import os

# Get IPBus
from PyChipsUser import *


#
class GLIB:

    ipbus = False

    def __init__(self, ipaddress = 0):
        if (ipaddress == 0):
            f = open(os.path.dirname(os.path.abspath(__file__)) + "/ttim_ip.dat", "r")
            ipaddress = f.readline().strip()
            f.close()
        ipbusAddrTable = AddressTable(os.path.dirname(os.path.abspath(__file__)) + "/register_mapping.dat")
        self.ipbus = ChipsBusUdp(ipbusAddrTable, ipaddress, 50001)

    def get(self, register):
        try:
            return self.ipbus.read(register)
        except ChipsException as e:
            pass

    def set(self, register, value):
        try:
            return self.ipbus.write(register, value)
        except ChipsException as e:
            pass

    def fifoRead(self, register, depth = 1):
        try:
            return self.ipbus.fifoRead(register, depth)
        except ChipsException as e:
            pass

    def blockRead(self, register, depth = 1):
        try:
            return self.ipbus.blockRead(register, depth)
        except ChipsException as e:
            pass

    def fifoWrite(self, register, data):
        try:
            return self.ipbus.fifoWrite(register, data)
        except ChipsException as e:
            pass

    def blockWrite(self, register, data):
        try:
            return self.ipbus.blockWrite(register, depth)
        except ChipsException as e:
            pass

    def get2OH(self, opto, register):
        try:
            return self.ipbus.read(register, ((opto & 0xf) << 20))
        except ChipsException as e:
            pass

    def set2OH(self, opto, register, value):
        try:
            return self.ipbus.write(register, value, ((opto & 0xf) << 20))
        except ChipsException as e:
            pass
