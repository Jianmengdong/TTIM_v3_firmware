from TTIM_v2 import *
from time import sleep
import platform


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


def main():
    """This script is used for debug and test purpose. Function needed is based on Padova BEC_timing.py"""

    vr = platform.python_version()
    print("Python version is %s" % vr)
    if int(vr.split('.')[0]) != 3:
        print("Please use Python3.x!")
        exit()
    # ttim_ip = "192.168.10.11"
    ttim = TTIM()
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
                    "8 = broadcast idle\n"
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
                    )
        if cmd == "q":
            exit()
        elif cmd == "1":
            ttim.set("inject_reset", 4)
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
            ttim.set("chb_req", 1)
            i = 0
            while i < 1:
                grant = ttim.get("system_status") >> 3 & 1
                # print(grant)
                if grant == 1:
                    i = 1
            ttim.set("chb_req", 4)
            ttim.set("chb_req", 0)
            sleep(1)
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
                temp = ttim.get("temp_regs")
                temp3 = (temp & 0x1ff) * 0.5
                temp2 = (temp >> 9 & 0x1ff) * 0.5
                temp1 = (temp >> 18) * 0.5
                voltage = ttim.get("pwr_regs")
                current = (voltage >> 24) * 0.0025
                VDD = (voltage >> 12 & 0xfff) * 0.025
                Vttim = (voltage & 0xfff) * 0.001
                print("Temperature:")
                print("Left: %.1f ℃  Middle: %.1f ℃  Right: %.1f ℃" % (temp1, temp3, temp2))
                print("Current: %.3f A   Vin: %.2f V   V_ttim: %.3f V" % (current, VDD, Vttim))
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
        else:
            print("wrong input")


if __name__ == "__main__":
    main()
