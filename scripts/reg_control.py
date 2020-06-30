from ipbus import *
# from time import sleep


def main():
    # ttim_ip = "192.168.10.11"
    ttim = GLIB()
    print("*" * 20)
    print("  TTIM_v2 console")
    print("")
    print("Please input command(input 'quit' to exit: \n"
          "To read a register, just input the register name;\n"
          "to write to a register, input the name and value(in HEX), separate with space\n")
    while True:
        command = input("cmd: ")
        if command == "quit":
            break
        else:
            cmd_list = command.split()
            if len(cmd_list) == 1:
                get_value = hex(ttim.get(cmd_list[0]))
                print("%s is %s" % (cmd_list[0], get_value))
            elif len(cmd_list) == 2:
                value = int(cmd_list[1], 16)
                set_value = hex(ttim.set(cmd_list[0], value))
                print("%s is set to %s" % (cmd_list[0], set_value))
            else:
                print("Wrong input format!")
        # sleep(1)


if __name__ == "__main__":
    main()
