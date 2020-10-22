import os
import binascii
import struct
from time import sleep
from TTIM_v2 import TTIM


def status_check(reg):
    status = bin((reg & 0xffc0) >> 6)[2:]
    return len(status), status


def check_error(st, f):
    error_status = st & 0x3f
    if error_status == 0:
        return 0
    elif error_status == 0b11:
        print("ID code error")
    elif error_status == 0b101:
        print("Erase error")
    elif error_status == 0b1001:
        print("Program error")
    elif error_status == 0b10001:
        print("Timeout error")
    elif error_status == 0b10101:
        print("Erase timeout")
    elif error_status == 0b1101:
        print("Program timeout")
    elif error_status == 0b100001:
        print("CRC error")
    else:
        print("Unknown error")
    f.close()
    exit()


def main():
    hw = TTIM()
    print("remote update start...")
    hw.update_set(0)
    hw.update_set(1)
    f = open(os.path.dirname(os.path.abspath(__file__)) + "/TTIM_v3_top.bin", 'rb')
    print("Checking ID code...")
    while True:
        reg = hw.update_status()
        print(hex(reg))
        length, status = status_check(reg)
        check_error(reg, f)
        if length >= 3 and status[-3] == "1":
            print("ID check OK")
            break
        sleep(0.1)
    print("Erasing...")
    while True:
        reg = hw.update_status()
        length, status = status_check(reg)
        check_error(reg, f)
        if length >= 5 and status[-5] == "1":
            print("Erase OK")
            break
        sleep(0.5)
    # # f.seek(0x100)
    done = 0
    addr = 0xB40000
    print("Programming...")
    progress = 0
    while addr < 0x1640000:
        status = hw.update_status()
        fifo_status = status >> 15
        print(progress, hex(addr), hex(status))
        check_error(status, f)
        if fifo_status == 1:
            line_number = 0
            word_cnt = 0
            # while line_number < 32:
            #     line = "FF"
            #     if done == 0:
            #         for i in range(0, 16):
            #             byte = binascii.b2a_hex(f.read(1))
            #             if (str(byte)) == "b''":
            #                 done = 1
            #                 string = "FF"
            #             else:
            #                 string = str(byte)[2:4]
            #             # print(byte, string)
            #             line = line + string
            #         hw.update_send(line)
            #         line_number += 1
            #         addr += 16
            #         # print(line)
            #         # line_number += 1
            #         # addr += 0x10
            #     else:
            #         line = line + "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
            #         # print(line)
            #         hw.update_send(line)
            #         line_number += 1
            #         addr += 16
            while word_cnt < 128:  # 32bit sending
                word = "FF"
                if done == 0:
                    for i in range(0, 4):
                        byte = binascii.b2a_hex(f.read(1))
                        if (str(byte)) == "b''":
                            done = 1
                            string = "FF"
                        else:
                            string = str(byte)[2:4]
                        # print(byte, string)
                        word = word + string
                    hw.update_send(word)
                    word_cnt += 1
                    addr += 4
                    # print(line)
                    # line_number += 1
                    # addr += 0x10
                else:
                    word = word + "FFFFFFFF"
                    # print(line)
                    hw.update_send(word)
                    word_cnt += 1
                    addr += 4
        progress += 1
        # sleep(0.2)
    while True:
        reg = hw.update_status()
        length, status = status_check(reg)
        check_error(reg, f)
        if length >= 6 and status[-6] == "1":
            print("program done")
            break
        sleep(0.1)
    # while True:
    #     reg = hw.update_status()
    #     length, status = status_check(reg)
    #     check_error(reg, f)
    #     if length >= 8 and status[-8] == "1":
    #         print("program switch word done")
    #         break
    #     sleep(0.1)
    print("Update done")
    f.close()


if __name__ == "__main__":
    main()
