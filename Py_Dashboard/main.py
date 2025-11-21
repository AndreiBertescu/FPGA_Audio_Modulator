import sys
import threading
from PyQt6 import QtWidgets

from buffer import RingBuffer, RegBlock
from network import producer_thread
from gui import Oscilloscope, BUFFER_SECONDS

BUFFER_SAMPLES = int(BUFFER_SECONDS * 48000)
IS_DEBUG = False


def main():
    # ring buffer for left channel only
    buffer_left = RingBuffer(BUFFER_SAMPLES)
    buffer_right = RingBuffer(BUFFER_SAMPLES)
    reg_block = RegBlock()

    # Start ethernet thread
    shutdown_evt = threading.Event()
    eth_th = threading.Thread(target=producer_thread,
                              args=(buffer_left, buffer_right, reg_block, IS_DEBUG, shutdown_evt),
                              daemon=True)
    eth_th.start()

    # Start GUI
    app = QtWidgets.QApplication(sys.argv)
    osc = Oscilloscope(buffer_left, buffer_right, reg_block)
    osc.show()

    # Handles exiting
    app.exec()
    shutdown_evt.set()
    eth_th.join(timeout=0.1)
    sys.exit(0)


if __name__ == "__main__":
    main()
