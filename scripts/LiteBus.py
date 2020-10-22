import socket
import TransElement
import binascii
import ChipsException


class LiteBus:
    MAX_TRANSACTION_ID = 7

    def __init__(self, addr_table, host_ip, host_port, local_port=None):
        self.__transID = 1
        self.addr_table = addr_table
        self.__host_addr = (host_ip, host_port)
        self.__socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        if local_port is not None:
            local_addr = ("", local_port)
            self.__socket.bind(local_addr)
        self.__socket.settimeout(2)

    def __get_transID(self):
        if self.__transID < LiteBus.MAX_TRANSACTION_ID:
            self.__transID += 1
        else:
            self.__transID = 1
        return 0

    def __make_read_transaction(self, name):
        reg_addr = self.addr_table.get_item(name).getAddress()
        trans_id = self.__transID
        transaction = TransElement.read_transaction(trans_id, reg_addr)
        #self.__get_transID()
        return transaction

    def __make_write_transaction(self, name, value):
        reg_addr = self.addr_table.get_item(name).getAddress()
        trans_id = self.__transID
        transaction = TransElement.write_transaction(trans_id, reg_addr, value)
        #self.__get_transID()
        return transaction

    def __check_frame(self, raw_data):
        # raw_data_hex = hex(raw_data)
        header = raw_data >> 60
        trans_id = (raw_data >> 56) & 0x7
        address = (raw_data >> 48) & 0xff
        data = raw_data & 0xffffffffffff
        return header, address, data
        # if trans_id == self.__transID:
            # return header, address, data
        # else:
            # return -1

    def read(self, register):
        transaction = hex(self.__make_read_transaction(register))[2:]
        trans_str = binascii.unhexlify(transaction)
        self.__socket.sendto(trans_str, self.__host_addr)
        raw_data = self.__socket.recvfrom(1024)[0]
        # print(raw_data)
        data_hex = int("0x" + binascii.hexlify(raw_data).decode(), 16)
        data = self.__check_frame(data_hex)[2]
        self.__get_transID()
        return data

    def write(self, register, value):
        transaction = hex(self.__make_write_transaction(register, value))[2:]
        trans_str = binascii.unhexlify(transaction)
        self.__socket.sendto(trans_str, self.__host_addr)
        raw_data = self.__socket.recvfrom(1024)[0]
        # data_hex = int("0x" + binascii.hexlify(raw_data).decode(), 16)
        # data = self.__check_frame(data_hex)[2]
        # self.__get_transID()
        return value

    def program(self, value_string):
        transaction = TransElement.program_transaction(value_string)
        # print(transaction)
        trans_str = binascii.unhexlify(transaction)
        # print(trans_str)
        self.__socket.sendto(trans_str, self.__host_addr)
        raw_data = self.__socket.recvfrom(1024)[0]
        return 0  #

    def program_status(self):
        transaction = 0x55550000
        trans_str = binascii.unhexlify(hex(transaction)[2:])
        self.__socket.sendto(trans_str, self.__host_addr)
        raw_data = self.__socket.recvfrom(1024)[0]
        status = int("0x" + binascii.hexlify(raw_data).decode(), 16)
        return status

    def program_set(self, command):
        # command_int = int(command, 16)
        # transaction = TransElement.program_transaction(command)
        transaction = (0x55 << 24) | command
        trans_str = binascii.unhexlify(hex(transaction)[2:])
        self.__socket.sendto(trans_str, self.__host_addr)
        raw_data = self.__socket.recvfrom(1024)[0]
        return 0

        # def show_registers(self):
        # return self.addr_table.show_registers

