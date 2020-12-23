from LiteBusEntity_v2 import *
from time import sleep
import socket
import platform
import os


def calibrate_ttc(ttim):
    print("start!")
    ttim.set("calib_enable", 1)
    sleep(2)
    ttim.set("calib_enable", 0)
    sleep(0.1)
    eye = ttim.get("tap_eye")
    print("TTC eye: %s" % eye)
    print("done!\n")


def calibrate_l1a(ttim):
    print("clear toggle bit...")
    i = 47
    s = ""
    current_ch = ttim.get("channel_sel")
    current_toggle = ttim.get("hit_toggle")
    while i >= 0:
        if i == current_ch:
            s = s + "0"
        else:
            s = s + "1"
        i = i - 1
    toggle_mask = int(s, 2)
    ttim.set("hit_toggle", current_toggle & toggle_mask)
    print("start")
    ttim.set("calib_enable", 2)
    sleep(2)
    ttim.set("calib_enable", 0)
    l1a_eye = ttim.get("l1a_tap_eye")
    # sleep(1)
    print("l1a eye: %s" % l1a_eye)
    if l1a_eye < 40:
        print("need invert toggle!")
        toggle = current_toggle | (1 << current_ch)
        ttim.set("hit_toggle", toggle)
        print("toggle inverted, restart!")
        ttim.set("calib_enable", 2)
        sleep(2)
        ttim.set("calib_enable", 0)
        l1a_eye = ttim.get("l1a_tap_eye")
        # sleep(1)
        print("l1a eye: %s" % l1a_eye)
    print("done!\n")


def calibrate_rx(ttim, channel, pair, show=False):
    ttim.set("channel_sel", channel)
    ttim.set("load_tap", 0)
    j = 0
    points = []
    tap = []
    error = []
    error_cnt = "error_cnt" + str(pair)
    if show is True:
        print("tap_cnt    error")
    # if sel == "1":
    while j < 63:
        # err_cnt1 = ttim.get("tap_err_cnt")
        ttim.set("tap_cnt", j)
        ttim.set("load_tap", pair)
        ttim.set("load_tap", 0)
        ttim.set("inject_reset", 1)
        ttim.set("inject_reset", 0)
        sleep(0.1)
        # err_cnt2 = ttim.get("tap_err_cnt")
        # err_cnt = err_cnt2 - err_cnt1
        err_cnt = ttim.get(error_cnt)
        if show is True:
            print("%d    %d" % (j, err_cnt))
        if err_cnt == 0:
            points.append(j)
        #     edge2 = j
        #     eye_width2 = eye_width2 + 1
        #     if eye_stop == 0:
        #         edge1 = j
        #         eye_width1 = eye_width1 + 1
        # else:
        #     eye_stop = 1
        #     eye_width2 = 0

        if err_cnt > 2000:
            err_cnt = 2000
        tap.append(j)
        error.append(err_cnt)
        j = j + 1
    # print(points)
    if len(points) > 0:
        i = 0
        edge = []  # eye edge list
        eye = 1
        while i < len(points):
            if i + 1 == len(points):
                edge.append((points[i + 1 - eye], points[i]))
            elif points[i+1] - points[i] == 1:  # consecutive tap means inside eye
                eye += 1
            else:
                edge.append((points[i+1-eye], points[i]))
                eye = 1
            i += 1
        # print(edge)
        tap_cnt = (edge[0][0] + edge[0][1]) // 2
        eye = edge[0][1] - edge[0][0]
        for i in range(len(edge) - 1):
            eye2 = edge[i+1][1] - edge[i+1][0]
            if eye2 > eye:
                eye = eye2
                tap_cnt = (edge[i+1][0] + edge[i+1][1]) // 2
        # if eye_width1 >= eye_width2:
        #     tap_cnt = edge1 - eye_width1 // 2
        # else:
        #     tap_cnt = edge2 - eye_width2 // 2
        ttim.set("tap_cnt", tap_cnt)
        ttim.set("load_tap", pair)
        ttim.set("load_tap", 0)
        ttim.set("inject_reset", 1)
        ttim.set("inject_reset", 0)
        return tap_cnt, tap, error
    else:
        return 99, tap, error  # no eye found


def read_temperature(ttim):
    temp = ttim.get("temp_regs")
    voltage = ttim.get("pwr_regs")
    fpga_reg = ttim.get("fpga_regs")
    fpga_temp = (fpga_reg >> 24) * 503.975 / 4096 - 273.15
    vccint = (fpga_reg >> 12 & 0xfff) * 3.0 / 4096
    vccaux = (fpga_reg & 0xfff) * 3.0 / 4096
    temp3 = (temp & 0x1ff) * 0.5
    temp2 = (temp >> 9 & 0x1ff) * 0.5
    temp1 = (temp >> 18) * 0.5
    current = (voltage >> 24) * 0.0025
    VDD = (voltage >> 12 & 0xfff) * 0.025
    Vttim = (voltage & 0xfff) * 0.001
    return (temp1, temp2, temp3, fpga_temp), (vccint, vccaux, current, VDD, Vttim)


def read_error_cnt(ttim, channel):
    ttim.set("channel_sel", channel)
    cnt1 = ttim.get("error_cnt1")
    cnt2 = ttim.get("error_cnt2")
    return cnt1, cnt2


def change_ip(ttim, ip):
    string = "ip set " + ip + "\r"
    ttim.uart_send(string)
    return 0


def uart_send(ttim, cmd: str):
    """max command length should be less than 500 bytes"""
    # string = "\r"
    # string = cmd + "\r"
    # string = cmd
    ttim.uart_send("\r")
    for i in range(len(cmd)):
        ttim.uart_send(cmd[i])
        sleep(0.1)
    ttim.uart_send("\r")
    return 0


def main():
    """This script is used for debug and test purpose, supplies some frequently used control commands for the BEC"""

    vr = platform.python_version()
    print("Python version is %s" % vr)
    if int(vr.split('.')[0]) != 3:
        print("Please use Python3.x!")
        exit()
    # ttim_ip = "192.168.10.11"
    f = open(os.path.dirname(os.path.abspath(__file__)) + "/TTIM_ip.dat")
    host_ip = f.readline().strip()
    f.close()
    reg = os.path.dirname(os.path.abspath(__file__)) + "/TTIM_v2_registers.dat"
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("", 2000))
    sock.settimeout(2)
    ttim = TTIM(host_ip, reg, sock)
    # ttim = TTIM("192.168.10.120", reg)
    print("*" * 20)
    print("  TTIM_v2 test script")
    print("")
    ch_i = ttim.get("channel_sel") + 1
    while True:
        cmd = input("enter the number of the function, q to exit\n"
                    "1 = 1588 ptp enable\n"
                    "2 = 1588 ptp disable\n"
                    "3 = change channel mask\n"
                    "4 = select GCU channel\n"
                    "5 = TTCRX error report of current channel\n"
                    "6 = PRBS error report of current channel\n"
                    "7 = broadcast rst errors\n"
                    "8 = set test mode\n"
                    "9 = GCU TTC calibration of current channel\n"
                    "10 = GCU L1A calibration of current channel\n"
                    "11 = toggle hit bits\n"
                    "12 = swap SC/nhit link\n"
                    "13 = show system status\n"
                    "14 = reset local error counter\n"
                    "15 = generate fake nhit\n"
                    "16 = set delay tap\n"
                    "17 = manual trigger\n"
                    "18 = sma select\n"
                    "19 = hit l1a debug\n"
                    "20 = change mini-WR IP\n"
                    )
        if cmd == "q":
            exit()
        elif cmd == "1":
            check = ttim.set("inject_reset", 4)
            print(type(check))
            print(check)
            sleep(1)
            print("done!\n")
        elif cmd == "2":
            ttim.set("inject_reset", 0)
            sleep(1)
            print("done!\n")
        elif cmd == "3":
            print("Current mask: %s" % hex(ttim.get("channel_mask")))
            mask = input("Input channel mask('1' to enable): ")
            if mask is None:
                pass
            else:
                mask_int = int(mask, 16)
                ttim.set("channel_mask", mask_int)
                print("channel mask set to %s\n" % mask)
                sleep(1)
        elif cmd == "4":
            ch = input("input GCU channel(1 - 48, 0 to check current channel): ")
            if ch == "0":
                ch_i = ttim.get("channel_sel") + 1
                sleep(1)
                print("Current channel %d" % ch_i)
            else:
                ch_i = int(ch, 10) - 1
                ttim.set("channel_sel", ch_i)
                sleep(1)
                print("done!\n")
        elif cmd == "5":
            sbit_error_cnt = ttim.get("sbit_error_cnt")
            dbit_error_cnt = ttim.get("dbit_error_cnt")
            comm_error_cnt = ttim.get("comm_error_cnt")
            print("channel %d sbit_error_cnt: %d" % (ch_i, sbit_error_cnt))
            print("channel %d dbit_error_cnt: %d" % (ch_i, dbit_error_cnt))
            print("channel %d comm_error_cnt: %d\n" % (ch_i, comm_error_cnt))
            sleep(1)
        elif cmd == "6":
            error_cnt1 = ttim.get("error_cnt1")
            error_cnt2 = ttim.get("error_cnt2")
            error_time1 = ttim.get("error_time1")
            error_time2 = ttim.get("error_time2")
            print("channel %d error_cnt1: %d" % (ch_i, error_cnt1))
            print("channel %d error_cnt2: %d" % (ch_i, error_cnt2))
            print("channel %d error_time1: %d" % (ch_i, error_time1))
            print("channel %d error_time2: %d\n" % (ch_i, error_time2))
            sleep(1)
        elif cmd == "7":
            ttim.set("chb_req", 1)
            i = 0
            while i < 1:
                grant = ttim.get("system_status") >> 3 & 1
                if grant == 1:
                    i = 1
            ttim.set("chb_req", 2)
            ttim.set("chb_req", 0)
            sleep(1)
            print("done!\n")
        elif cmd == "8":
            test_mode = input("input test mode in HEX: ")
            ttim.set("test_mode", int(test_mode, 16))
            sleep(0.1)
            print("done!\n")
        elif cmd == "9":
            calibrate_ttc(ttim)
            # print("start!")
            # ttim.set("calib_enable", 1)
            # sleep(2)
            # ttim.set("calib_enable", 0)
            # sleep(1)
            # eye = ttim.get("tap_eye")
            # print("TTC eye: %s" % eye)
            # print("done!\n")
        elif cmd == "10":
            calibrate_l1a(ttim)
            # print("clear toggle bit...")
            # i = 47
            # s = ""
            # current_ch = ttim.get("channel_sel")
            # current_toggle = ttim.get("hit_toggle")
            # while i >= 0:
            #     if i == current_ch:
            #         s = s + "0"
            #     else:
            #         s = s + "1"
            #     i = i - 1
            # toggle_mask = int(s, 2)
            # ttim.set("hit_toggle", current_toggle & toggle_mask)
            # print("start")
            # ttim.set("calib_enable", 2)
            # sleep(3)
            # ttim.set("calib_enable", 0)
            # l1a_eye = ttim.get("l1a_tap_eye")
            # # sleep(1)
            # print("l1a eye: %s" % l1a_eye)
            # if l1a_eye < 40:
            #     print("need invert toggle!")
            #     toggle = current_toggle | (1 << current_ch)
            #     ttim.set("hit_toggle", toggle)
            #     print("toggle inverted, restart!")
            #     ttim.set("calib_enable", 2)
            #     sleep(3)
            #     ttim.set("calib_enable", 0)
            #     l1a_eye = ttim.get("l1a_tap_eye")
            #     # sleep(1)
            #     print("l1a eye: %s" % l1a_eye)
            # print("done!\n")
        elif cmd == "11":
            print("current toggle value: %s" % hex(ttim.get("hit_toggle")))
            tg = int(input("hit toggle(in hex): "), 16)
            ttim.set("hit_toggle", tg)
            sleep(1)
            print("done!\n")
        elif cmd == "12":
            swap = int(input("swap value (in hex): "), 16)
            ttim.set("pair_swap", swap)
            sleep(1)
            print("done!\n")
        elif cmd == "13":
            status = ttim.get("system_status")
            # print(hex(status))
            sleep(0.1)
            version = hex(status >> 4)
            pll = status & 1
            ttc_ready = status >> 1 & 1
            rx_align = status >> 2 & 1
            print("Hardware/Firmware version: %s" % version)
            print("Local PLL: %d" % pll)
            print("TTC TX ready: %d" % ttc_ready)
            print("Trigger link aligned: %d" % rx_align)
            ttc_align = hex(ttim.get("channel_rdy"))
            print("TTC RX ready: %s \n" % ttc_align)
            if version[2] == "3":
                (temp1, temp2, temp3, fpga_temp), (vccint, vccaux, current, VDD, Vttim) = read_temperature(ttim)
                print("Temperature:")
                print("Left: %.1f ℃  Middle: %.1f ℃  Right: %.1f ℃  FPGA: %.1f ℃" % (temp1, temp3, temp2, fpga_temp))
                print("BEC Current: %.3f A   Vin: %.2f V   V_ttim: %.3f V" % (current, VDD, Vttim))
                print("FPGA VCCINT:  %.3f V   VCCAUX:  %.3f V" % (vccint, vccaux))
            sleep(1)
        elif cmd == "14":
            ptp = ttim.get("inject_reset")
            reset = ptp | 1
            clear = ptp & 4
            ttim.set("inject_reset", reset)
            sleep(0.1)
            ttim.set("inject_reset", clear)
            sleep(1)
            print("done!\n")
        elif cmd == "15":
            rpy = input("y/n?: ")
            if rpy == "y":
                ttim.set("gen_fake_nhit", 1)
            else:
                ttim.set("gen_fake_nhit", 0)
            sleep(0.1)
        elif cmd == "16":
            ch = input("input GCU channel(1 - 48, 0 to check current channel): ")
            ch_i = int(ch, 10) - 1
            ttim.set("channel_sel", ch_i)
            tap = int(input("input tap value: "), 10)
            ttim.set("tap_cnt", tap)
            ch_sel = input("1 -> RX1, 2 -> RX2")
            if ch_sel == "1":
                ttim.set("load_tap", 1)
                ttim.set("load_tap", 0)
                ttim.set("inject_reset", 1)
                ttim.set("inject_reset", 0)
            else:
                ttim.set("load_tap", 2)
                ttim.set("load_tap", 0)
                ttim.set("inject_reset", 1)
                ttim.set("inject_reset", 0)
        elif cmd == "17":
            pass
        elif cmd == "18":
            sma_sel = input("0-> RX1  1-> RX2")
            ttim.set("sma_sel", int(sma_sel))
            sleep(0.1)
        elif cmd == "19":
            hit = hex(ttim.get("hit_debug"))
            l1a = bin(ttim.get("l1a_debug"))
            print("hit in HEX: ", hit)
            print("l1a in BIN: ", l1a)
            sleep(1)
        elif cmd == "20":
            ip = input("new IP: ")
            # change_ip(ttim, ip)
            uart_send(ttim, ip)
        else:
            print("wrong input")


if __name__ == "__main__":
    main()
