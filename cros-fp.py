#!/usr/bin/env python3
import os
import sys
import subprocess
from urllib.request import urlopen, urlretrieve
from pathlib import Path

def ec_command(command):
    result = subprocess.check_output(f"./ectool --name=cros_fp {command}", shell=True, text=True)
    return result

def download_ectool():
    if not Path("./ectool").exists():
        urlretrieve(url="https://tree123.org/chrultrabook/utils/ectool", filename="./ectool")
        os.system("chmod +x ./ectool")

def set_seed():
    ec_command("fpseed aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    print("Seed set")

def enroll():
    ec_command("fpmode reset")
    ec_command("fpmode enroll")
    print("Press your finger to the sensor")
    ecmode = ""
    while "(0x0)" not in ecmode:
        ecmode = ec_command("fpmode")
        #print(ecmode)
        if "(0x10)" in ecmode:
            print("Press your finger to the sensor")
            ec_command("fpmode enroll")
    print("Enrolled!")

def match():
    ec_command("fpmode reset")
    ec_command("fpmode match")
    print("Press an enrolled finger to the sensor")
    ecmode = ""
    while "(0x0)" not in ecmode:
        ecmode = ec_command("fpmode")
    stats = ec_command("fpstats")
    match = stats.split("\n")[2].split(" ")[6]
    print(f"Fingerprint matched: {match[0]}")
    return match

def dl_temp():
    ec_command("fpmode reset")
    temp = input("Which fingerprint would you like to download?: ")
    os.system(f"./ectool --name=cros_fp fptemplate {temp}")

if __name__ == "__main__":
    download_ectool()
    set_seed()
    enroll()
    match()
    dl_temp()
