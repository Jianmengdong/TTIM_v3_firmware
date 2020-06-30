from ipbus import *
from time import sleep


def calibrate_ttc(ttim):
    print("start!")
    ttim.set("calib_enable", 2)
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
    current_ch = ttim.get("channel_selr")
    tg1 = hex(ttim.get("hit_toggle1r"))
    tg2 = hex(ttim.get("hit_toggle2r"))
    toggle = tg2 + tg1[2:]
    while i >= 0:
        if i == current_ch:
            s = s + "0"
        else:
            s = s + "1"
        i = i - 1
    toggle_mask = int(s, 2)
    ttim.set("hit_toggle", int(toggle, 16) & toggle_mask)
    print("start")
    ttim.set("l1a_calib_enable", 4)
    sleep(2)
    ttim.set("l1a_calib_enable", 0)
    l1a_eye = ttim.get("l1a_tap_eye")
    # sleep(1)
    print("l1a eye: %s" % l1a_eye)
    if l1a_eye < 40:
        print("need invert toggle!")
        toggle = int(toggle, 16) | (1 << current_ch)
        ttim.set("hit_toggle", toggle)
        print("toggle inverted, restart!")
        ttim.set("l1a_calib_enable", 4)
        sleep(2)
        ttim.set("l1a_calib_enable", 0)
        l1a_eye = ttim.get("l1a_tap_eye")
        # sleep(1)
        print("l1a eye: %s" % l1a_eye)
    print("done!\n")


def main():
    ttim = GLIB()
    print("TTIM version: ", hex(ttim.get("version")))
    print("WR clock locked: ", hex(ttim.get("pll_locked")))
    print("Trigger link aligned: ", hex(ttim.get("rx_aligned")))
    ch_i = ttim.get("channel_selr") + 1
    while True:
        cmd = input("enter the number of the function, q to exit\n"
                    "1 = 1588 ptp enable\n"
                    "2 = set trigger window\n"
                    "3 = change channel mask\n"
                    "4 = select GCU channel\n"
                    "5 = TTCRX error report of current channel\n"
                    "6 = PRBS error report of current channel\n"
                    "7 = broadcast rst errors\n"
                    "8 = change test mode\n"
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
                    "19 = trigger source configure\n"
                    "20 = trigger threshold\n"
                    "21 = trigger period\n"
                    "22 = tx1 source select\n"
                    "23 = tx1 invert\n"
                    )
        if cmd == "q":
            exit(0)
        elif cmd == '1':
            ptp = input("1 to enable, 0 to disable: ")
            ttim.set("ptp_enable", int(ptp))
            sleep(0.5)
            print("done!\n")
        elif cmd == '2':
            window = input("input trigger window, 0 - 9: ")
            ttim.set("trig_window", int(window))
            sleep(0.5)
            print("done!\n")
        elif cmd == '3':
            ch_mask = input("input mask in HEX: ")
            if len(ch_mask) <= 8:
                ttim.set("channel_mask1", int(ch_mask, 16))
                ttim.set("channel_mask2", 0)
            else:
                ttim.set("channel_mask1", int(ch_mask[-8:], 16))
                ttim.set("channel_mask2", int(ch_mask[:-8], 16))
            sleep(0.5)
            print("done!\n")
        elif cmd == '4':
            ch = input("input GCU channel(1 - 48, 0 to check current channel): ")
            if ch == "0":
                ch_i = ttim.get("channel_selr") + 1
                sleep(1)
                print("Current channel %d" % ch_i)
            else:
                ch_i = int(ch, 10) - 1
                ttim.set("channel_sel", ch_i)
                sleep(0.5)
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
            error_time1_1 = hex(ttim.get("error_time1_1"))
            error_time1_2 = hex(ttim.get("error_time1_2"))
            error_time1 = error_time1_2 + error_time1_1[2:]
            error_time2_1 = hex(ttim.get("error_time2_1"))
            error_time2_2 = hex(ttim.get("error_time2_2"))
            error_time2 = error_time2_2 + error_time2_1[2:]
            print("channel %d error_cnt1: %d" % (ch_i, error_cnt1))
            print("channel %d error_cnt2: %d" % (ch_i, error_cnt2))
            print("channel %d error_time1: %s" % (ch_i, error_time1))
            print("channel %d error_time2: %s\n" % (ch_i, error_time2))
            sleep(0.5)
        elif cmd == '7':
            ttim.set("chb_req", 1)
            i = 0
            while i < 1:
                grant = ttim.get("chb_grant")
                # print(grant)
                if grant == 1:
                    i = 1
            ttim.set("ttc_rst_err", 2)
            sleep(0.5)
            ttim.set("ttc_rst_err", 0)
            print("done!\n")
        elif cmd == '8':
            test_mode = input("input test mode in HEX: ")
            if len(test_mode) <= 8:
                ttim.set("test_mode1", int(test_mode, 16))
                ttim.set("test_mode2", 0)
            else:
                ttim.set("test_mode1", int(test_mode[-8:], 16))
                ttim.set("test_mode2", int(test_mode[:-8], 16))
            sleep(0.5)
            print("done!\n")
        elif cmd == '9':
            calibrate_ttc(ttim)
        elif cmd == '10':
            calibrate_l1a(ttim)
        elif cmd == '11':
            tg1 = hex(ttim.get("hit_toggle1r"))
            tg2 = hex(ttim.get("hit_toggle2r"))
            toggle = tg2 + tg1[2:]
            print("current toggle value: %s" % toggle)
            tg = input("hit toggle(in hex): ")
            if len(tg) <= 8:
                ttim.set("hit_toggle1", int(tg, 16))
                ttim.set("hit_toggle2", 0)
            else:
                ttim.set("hit_toggle1", int(tg[-8:], 16))
                ttim.set("hit_toggle2", int(tg[:-8], 16))
            sleep(0.5)
            print("done!\n")
        elif cmd == "12":
            swap = input("swap value (in hex): ")
            if len(swap) <= 8:
                ttim.set("pair_swap1", int(swap, 16))
                ttim.set("pair_swap2", 0)
            else:
                ttim.set("pair_swap1", int(swap[-8:], 16))
                ttim.set("pair_swap2", int(swap[:-8], 16))
            sleep(0.5)
            print("done!\n")
        elif cmd == '13':
            print("TTIM version: ", hex(ttim.get("version")))
            print("WR clock locked: ", hex(ttim.get("pll_locked")))
            print("Trigger link aligned: ", hex(ttim.get("rx_aligned")))
            print("TTC tx ready: ", hex(ttim.get("tx_ready")))
            temp = ttim.get("temperature")
            voltage1 = ttim.get("voltage1")
            voltage2 = ttim.get("voltage2")
            voltage3 = ttim.get("voltage3")
            temp3 = (temp & 0x1ff) * 0.5
            temp2 = (temp >> 9 & 0x1ff) * 0.5
            temp1 = (temp >> 18) * 0.5
            temp_fpga = (voltage2 >> 12) * 503.975 / 4096 - 273.15
            print("Temperature:")
            print("Left: %.1f ℃  Middle: %.1f ℃  Right: %.1f ℃  FPGA: %.1f ℃" % (temp1, temp3, temp2, temp_fpga))
            current = (voltage1 >> 12) * 0.0025
            VDD = (voltage1 & 0xfff) * 0.025
            Vttim = (voltage2 & 0xfff) * 0.001
            Vint = (voltage3 >> 12) * 3.0 / 4096
            Vaux = (voltage3 & 0xfff) * 3.0 / 4096
            print("Current: %.3f A   Vin: %.2f V   V_ttim: %.3f V" % (current, VDD, Vttim))
            print("VCCINT: %.2f V   VCCAUX: %.3f V" % (Vint, Vaux))
            sleep(0.5)
        elif cmd == '14':
            ttim.set("reset_err", 4)
            ttim.set("reset_err", 0)
            sleep(0.5)
            print("done!\n")
        elif cmd == "15":
            rpy = input("y/n?: ")
            if rpy == "y":
                ttim.set("gen_fake_nhit", 1)
            else:
                ttim.set("gen_fake_nhit", 0)
            sleep(0.1)
        elif cmd == "16":
            tap = int(input("input tap value: "), 10)
            ttim.set("tap_cnt", tap)
            ch_sel = input("1 -> RX1, 2 -> RX2")
            if ch_sel == "1":
                ttim.set("load1", 1)
                ttim.set("load1", 0)
                ttim.set("reset_err", 4)
                ttim.set("reset_err", 0)
            else:
                ttim.set("load2", 2)
                ttim.set("load2", 0)
                ttim.set("reset_err", 4)
                ttim.set("reset_err", 0)
            print("tap set to: %d" % ttim.get("tap_cntr"))
            sleep(0.5)
            print("done!\n")
        elif cmd == "17":
            ttim.set("sma_sel", 1)
        elif cmd == "18":
            sma_sel = input("0-> RX1  1-> RX2")
            ttim.set("sma_sel", int(sma_sel))
            sleep(0.1)
        elif cmd == '19':
            trig_src = input("input trigger source in HEX: ")
            ttim.set("en_trig", int(trig_src))
            sleep(0.5)
            print("done!\n")
        elif cmd == '20':
            th = input("input trigger threshold in HEX: ")
            ttim.set("trig_threshold", int(th))
            sleep(0.5)
            print("done!\n")
        elif cmd == '21':
            period = input("input trigger period in HEX: ")
            ttim.set("trig_period", int(period))
            sleep(0.5)
            print("done!\n")
        elif cmd == '22':
            tx1_sel = input("input tx1_sel set in HEX: ")
            if len(tx1_sel) <= 8:
                ttim.set("tx1_sel1", int(tx1_sel, 16))
                ttim.set("tx1_sel2", 0)
            else:
                ttim.set("tx1_sel1", int(tx1_sel[-8:], 16))
                ttim.set("tx1_sel2", int(tx1_sel[:-8], 16))
            sleep(0.5)
            print("done!\n")
        elif cmd == '23':
            inv_o1 = input("input tx1 invert in HEX: ")
            if len(inv_o1) <= 8:
                ttim.set("inv_o1_1", int(inv_o1, 16))
                ttim.set("inv_o1_2", 0)
            else:
                ttim.set("inv_o1_1", int(inv_o1[-8:], 16))
                ttim.set("inv_o1_2", int(inv_o1[:-8], 16))
            sleep(0.5)
            print("done!\n")

    pass


if __name__ == "__main__":
    main()
