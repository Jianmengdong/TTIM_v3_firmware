This folder contains the python scripts used for TTIM_v2 test. The mini-WR need to be plugged to use these scripts!
These scripts are writen in Python3.x, and will complain if you use other python version.

*BEC_timing.py
    The interface will show instructions about different command.

*prbs_eye_scan.py
    Scan the eye of the selected channel.
    Has some bug when glitches happen. To be fixed.......

*eye_scan.py
    Scan the eye of selected channel.
    To scan the L1A eye, the TTC channel must be calibrated first using BEC_timing.py

*reg_control.py
    A general scripts to control all the registers implemented inside the firmware.
    "show registers" command will type all the registers names.
    To read from a register, just type its name.
        Example: cmd: channel_mask -- this will return the current channel_mask value
    To write to a register, type the name and value (in HEX), seperated with space.
        Example: cmd: channel_mask FB  -- this will enable channel 1 2 4 5 6 7 8.
        
*TTIM_v2_registers.dat
    this file contains the registers names and their address.
        
*TTIM_ip.dat
    this file contains the IP address of the TTIM.