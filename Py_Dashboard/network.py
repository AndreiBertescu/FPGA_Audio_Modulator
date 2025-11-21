import time
import threading
import numpy as np
from scapy.all import sniff
from scapy.layers.l2 import Ether
from scapy.sendrecv import sendp, AsyncSniffer

from buffer import RingBuffer, RegBlock

DBG_FREQ = 10
SEND_INTERVAL_MS = 50
ETHERTYPE = 0x88B5
SRC_MAC = "80:1F:12:CA:83:63"
DST_MAC = "FF:FF:FF:FF:FF:FF"


def producer_thread(buf_left: RingBuffer, buf_right: RingBuffer, reg_block: RegBlock, en_debug: bool,
                    shutdown_evt: threading.Event):
    # Generate 1 kHz sin wave
    if en_debug:
        t = 0.0
        pkt_time = np.arange(250) * (1 / 48000)

        while not shutdown_evt.is_set():
            phase = (2 * np.pi * DBG_FREQ) * (t + pkt_time)
            left = np.round(np.sin(phase) * (2 ** 22 - 1)).astype(np.int32)
            right = -left

            buf_left.write(left)
            buf_right.write(right)

            # advance time and sleep until next packet
            t += 250 / 48000
            time.sleep(250 / 48000)
        return

    # Handle ethernet transactions
    def handle_packet(pkt):
        if pkt.haslayer("Ethernet") and pkt.type == ETHERTYPE:
            if pkt.src.lower() != SRC_MAC.lower():
                return

            payload = bytes(pkt.payload)
            n = len(payload) // 6
            data = np.frombuffer(payload[6:n * 6], dtype=np.uint8).reshape(-1, 6)

            left = (data[:, 0].astype(np.int32) << 16) | (data[:, 1].astype(np.int32) << 8) | data[:, 2].astype(
                np.int32)
            left = (left ^ (1 << 23)) - (1 << 23)

            right = (data[:, 3].astype(np.int32) << 16) | (data[:, 4].astype(np.int32) << 8) | data[:, 5].astype(
                np.int32)
            right = (right ^ (1 << 23)) - (1 << 23)

            buf_left.write(left)
            buf_right.write(right)

    # sniff(iface="Ethernet", prn=handle_packet, store=False)
    # Start sniffer in the background so it doesn't block the sender
    sniffer = AsyncSniffer(
        iface="Ethernet",
        prn=handle_packet,
        store=False,
        lfilter=lambda p: p.haslayer(Ether) and p[Ether].type == ETHERTYPE
    )
    sniffer.start()

    # Main loop for sending reg_block updates
    while not shutdown_evt.is_set():
        payload = b"".join(x.to_bytes(4, "big") for x in reg_block.dump())

        eth = Ether(src=DST_MAC, dst=SRC_MAC, type=ETHERTYPE)
        sendp(eth / payload, iface="Ethernet", verbose=False)

        time.sleep(SEND_INTERVAL_MS / 1000.0)  # slight yield for CPU
