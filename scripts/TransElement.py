import LiteBusHeader


def read_transaction(trans_id, reg_addr):
    header = LiteBusHeader.makeheader(trans_id, 0)
    transaction = (header << 56) | (reg_addr << 48) | 0
    return transaction


def write_transaction(trans_id, reg_addr, value):
    header = LiteBusHeader.makeheader(trans_id, 1)
    transaction = (header << 56) | (reg_addr << 48) | (value & 0xffffffffffff)
    return transaction


def program_transaction(value_string):
    transaction = LiteBusHeader.PROG_HEADER + value_string
    return transaction


def uart_transaction(string):
    return LiteBusHeader.UART_HEADER + string
