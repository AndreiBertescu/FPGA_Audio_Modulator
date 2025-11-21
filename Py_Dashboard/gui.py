import math

import numpy as np
import pyqtgraph as pg
from PyQt6 import QtWidgets, QtCore

from buffer import RingBuffer, RegBlock

PLOT_FPS = 30
BUFFER_SECONDS = 5.0
FFT_POINTS = 4096 * 4
FFT_WINDOW = "hann"  # hann, hamming, blackman


class Oscilloscope(QtWidgets.QMainWindow):
    def __init__(self, buf_left: RingBuffer, buf_right: RingBuffer, reg_block: RegBlock):
        super().__init__()
        self.buf_left = buf_left
        self.buf_right = buf_right
        self.reg_block = reg_block

        self.setWindowTitle("Audio Modulator Control Panel")
        self.resize(1280, 720)
        # self.showMaximized()

        self.time_step = 0
        self.amplitude_offset = 0
        self.amplitude = 0

        # FFT average helpers
        self._avg_buf_left = None
        self._avg_buf_right = None
        self._avg_idx = 0
        self._avg_count = 0

        # Central widget
        cw = QtWidgets.QWidget()
        self.setCentralWidget(cw)
        main_layout = QtWidgets.QHBoxLayout(cw)

        # Left side (plots)
        plots_layout = self.init_plots()
        pg.setConfigOptions(antialias=False)  # for raw speed

        # Right side (controls)
        self.amplitude_step_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.amplitude_step_slider.valueChanged.connect(self.on_amplitude_step_changed)
        self.amplitude_step_label = QtWidgets.QLabel("")
        self.amplitude_offset_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.amplitude_offset_slider.valueChanged.connect(self.on_amplitude_offset_changed)
        self.amplitude_offset_label = QtWidgets.QLabel("")

        self.fft_radio1 = QtWidgets.QRadioButton("Avg")
        self.fft_radio2 = QtWidgets.QRadioButton("MaxHold")
        self.fft_spinbox = QtWidgets.QSpinBox()

        self.volume_left_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.volume_right_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.volume_left_label = QtWidgets.QLabel("")
        self.volume_right_label = QtWidgets.QLabel("")

        self.delay_left_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.delay_right_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.delay_left_label = QtWidgets.QLabel("")
        self.delay_right_label = QtWidgets.QLabel("")

        self.mixer_radio1 = QtWidgets.QRadioButton("Pass-through")
        self.mixer_radio2 = QtWidgets.QRadioButton("Low-pass filter")
        self.mixer_radio3 = QtWidgets.QRadioButton("High-pass filter")
        self.mixer_radio4 = QtWidgets.QRadioButton("Band-pass filter")
        self.mixer_radio5 = QtWidgets.QRadioButton("Notch filter")
        self.mixer_radio6 = QtWidgets.QRadioButton("Distortion threshold")
        self.mixer_radio7 = QtWidgets.QRadioButton("Tremolo frequency")

        self.lpf_spinbox = QtWidgets.QSpinBox()
        self.hpf_spinbox = QtWidgets.QSpinBox()
        self.bpf_low_spinbox = QtWidgets.QSpinBox()
        self.bpf_high_spinbox = QtWidgets.QSpinBox()
        self.bsf_spinbox = QtWidgets.QSpinBox()

        self.distortion_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.tremolo_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.distortion_label = QtWidgets.QLabel("")
        self.tremolo_label = QtWidgets.QLabel("")

        controls_layout = self.init_controls()

        main_layout.addLayout(plots_layout, stretch=3)
        main_layout.addLayout(controls_layout, stretch=1)

        # Initialize the plot x/y axes
        self.x = np.linspace(-self.time_step, 0.0, 4800, dtype=np.float32)
        self.y = np.zeros(4800, dtype=np.float32)
        self.curve_left = self.plot_item_left.plot(self.x, self.y, pen=pg.mkPen(width=1))
        self.curve_right = self.plot_item_right.plot(self.x, self.y, pen=pg.mkPen(width=1))

        # Initialize the fft x/y axes
        self.x = np.linspace(0, FFT_POINTS, FFT_POINTS, dtype=np.float32)
        self.y = np.zeros(FFT_POINTS, dtype=np.float32)
        self.curve_fft_left = self.fft_item_left.plot(self.x, self.y, pen=pg.mkPen(width=1))
        self.curve_fft_right = self.fft_item_right.plot(self.x, self.y, pen=pg.mkPen(width=1))

        # Timer for updates
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_plot)
        self.timer.start(int(1000 / PLOT_FPS))

    def update_plot(self):
        # Y axis
        self.plot_item_left.setYRange(-100 * self.amplitude + self.amplitude_offset,
                                      100 * self.amplitude + self.amplitude_offset)
        self.plot_item_right.setYRange(-100 * self.amplitude + self.amplitude_offset,
                                       100 * self.amplitude + self.amplitude_offset)

        # X axis
        window_samples = int(self.time_step * 48000)
        t_axis = np.linspace(-self.time_step, 0.0, window_samples, dtype=np.float32)

        max_val = 2 ** 23  # max absolute value

        latest_left = (self.buf_left.read(window_samples) / max_val) * 100
        latest_right = (self.buf_right.read(window_samples) / max_val) * 100

        self.curve_left.setData(t_axis, latest_left)
        self.curve_right.setData(t_axis, latest_right)

        # FFT
        f_axis = self.buf_left.get_freq_axis(FFT_POINTS)

        # Compute FFTs (complex) of most recent samples
        Xl = self.buf_left.get_fft(FFT_POINTS, window=FFT_WINDOW)
        Xr = self.buf_right.get_fft(FFT_POINTS, window=FFT_WINDOW)

        # Convert to magnitude dBFS
        Pl = (np.abs(Xl) / (2 ** 23 * FFT_POINTS)) ** 2 + 1e-30
        Pr = (np.abs(Xr) / (2 ** 23 * FFT_POINTS)) ** 2 + 1e-30

        # Average hold over the last K frames
        self._avg_hold_push(Pl, Pr)
        Pl_avg, Pr_avg = self._avg_hold_get()

        # Update FFT plots
        self.curve_fft_left.setData(f_axis, 10.0 * np.log10(Pl_avg))
        self.curve_fft_right.setData(f_axis, 10.0 * np.log10(Pr_avg))

    def init_plots(self):
        # Left channel plot
        self.plot_widget_left = pg.PlotWidget()
        self.plot_widget_left.showGrid(x=True, y=True, alpha=0.5)

        self.plot_item_left = self.plot_widget_left.getPlotItem()
        self.plot_item_left.setLabel('left', 'Amplitude', units='%')
        self.plot_item_left.setLabel('bottom', 'Time', units='s')

        vb = self.plot_item_left.getViewBox()
        vb.setMouseEnabled(x=False, y=False)

        # Right channel plot
        self.plot_widget_right = pg.PlotWidget()
        self.plot_widget_right.showGrid(x=True, y=True, alpha=0.5)

        self.plot_item_right = self.plot_widget_right.getPlotItem()
        self.plot_widget_right.getAxis('left').setStyle(showValues=False)
        self.plot_item_right.setLabel('bottom', 'Time', units='s')

        vb = self.plot_item_right.getViewBox()
        vb.setMouseEnabled(x=False, y=False)

        plots_group = QtWidgets.QGroupBox("Left/Right channels")
        plots_layout = QtWidgets.QHBoxLayout()
        plots_layout.addWidget(self.plot_widget_left)
        plots_layout.addWidget(self.plot_widget_right)
        plots_group.setLayout(plots_layout)
        plots_group.setMinimumWidth(800)

        # Left fft plot
        self.fft_widget_left = pg.PlotWidget()
        self.fft_widget_left.showGrid(x=True, y=True, alpha=0.5)

        self.fft_item_left = self.fft_widget_left.getPlotItem()
        self.fft_item_left.setLabel('left', 'Amplitude', units='dBFS')
        self.fft_item_left.setLabel('bottom', 'Frequency', units='Hz')
        self.fft_item_left.setXRange(0, 25000)  # show 0..Nyquist
        self.fft_item_left.setYRange(-150, 0)  # typical dBFS range

        vb = self.fft_item_left.getViewBox()
        vb.setMouseEnabled(x=False, y=False)

        # Right fft plot
        self.fft_widget_right = pg.PlotWidget()
        self.fft_widget_right.showGrid(x=True, y=True, alpha=0.5)

        self.fft_item_right = self.fft_widget_right.getPlotItem()
        self.fft_item_right.getAxis('left').setStyle(showValues=False)
        self.fft_item_right.setLabel('bottom', 'Frequency', units='Hz')
        self.fft_item_right.setXRange(0, 25000)
        self.fft_item_right.setYRange(-150, 0)

        vb = self.plot_item_right.getViewBox()
        vb.setMouseEnabled(x=False, y=False)

        fft_group = QtWidgets.QGroupBox("Left/Right frequency spectrums")
        fft_layout = QtWidgets.QHBoxLayout()
        fft_layout.addWidget(self.fft_widget_left)
        fft_layout.addWidget(self.fft_widget_right)
        fft_group.setLayout(fft_layout)
        fft_group.setMinimumWidth(800)

        graphs_layout = QtWidgets.QVBoxLayout()
        graphs_layout.addWidget(plots_group)
        graphs_layout.addWidget(fft_group)

        return graphs_layout

    def init_controls(self):
        controls_layout = QtWidgets.QVBoxLayout()

        # Slider for time step
        self.time_step_slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)  # or Horizontal
        self.time_step_slider.setMinimum(0)
        self.time_step_slider.setMaximum(1000)
        self.time_step_slider.setValue(1000)
        self.time_step_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.time_step_slider.setTickInterval(
            int((self.time_step_slider.maximum() - self.time_step_slider.minimum()) / 10))
        self.time_step_slider.valueChanged.connect(self.on_timescale_changed)

        self.time_step_label = QtWidgets.QLabel("")
        self.time_step_label.setFixedWidth(55)
        self.time_step_label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_timescale_changed(1000)

        time_group = QtWidgets.QGroupBox("Time step")
        time_step = QtWidgets.QHBoxLayout()
        time_step.addWidget(self.time_step_label)
        time_step.addWidget(self.time_step_slider)
        time_group.setLayout(time_step)
        time_group.setFixedHeight(70)

        # Slider for amplitude
        self.amplitude_step_slider.setMinimum(10)
        self.amplitude_step_slider.setMaximum(100)
        self.amplitude_step_slider.setValue(20)
        self.amplitude_step_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.amplitude_step_slider.setTickInterval(
            int((self.amplitude_step_slider.maximum() - self.amplitude_step_slider.minimum()) / 10))

        self.amplitude_step_label.setFixedWidth(45)
        self.amplitude_step_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_amplitude_step_changed(20)

        amplitude_step_group = QtWidgets.QGroupBox("Amplitude")
        amplitude_step_layout = QtWidgets.QHBoxLayout()
        amplitude_step_layout.addWidget(self.amplitude_step_label)
        amplitude_step_layout.addWidget(self.amplitude_step_slider)
        amplitude_step_group.setLayout(amplitude_step_layout)

        # Slider for amplitude offset
        self.amplitude_offset_slider.setMinimum(-100)
        self.amplitude_offset_slider.setMaximum(100)
        self.amplitude_offset_slider.setValue(0)
        self.amplitude_offset_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.amplitude_offset_slider.setTickInterval(
            int((self.amplitude_offset_slider.maximum() - self.amplitude_offset_slider.minimum()) / 10))

        self.amplitude_offset_label.setFixedWidth(55)
        self.amplitude_offset_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_amplitude_offset_changed(0)

        amplitude_offset_group = QtWidgets.QGroupBox("Amplitude offset")
        amplitude_offset_layout = QtWidgets.QHBoxLayout()
        amplitude_offset_layout.addWidget(self.amplitude_offset_label)
        amplitude_offset_layout.addWidget(self.amplitude_offset_slider)
        amplitude_offset_group.setLayout(amplitude_offset_layout)

        amplitude_group = QtWidgets.QGroupBox("")
        amplitude_layout = QtWidgets.QHBoxLayout()
        amplitude_layout.addWidget(amplitude_step_group)
        amplitude_layout.addWidget(amplitude_offset_group)
        amplitude_group.setLayout(amplitude_layout)
        amplitude_group.setFixedHeight(100)

        # FFT
        self.fft_radio1.setChecked(True)
        self.fft_group = QtWidgets.QButtonGroup(self)
        self.fft_group.addButton(self.fft_radio1)
        self.fft_group.addButton(self.fft_radio2)

        self.fft_spinbox.setRange(1, 100)
        self.fft_spinbox.setValue(2)

        fft_group = QtWidgets.QGroupBox("FFT")
        fft_layout = QtWidgets.QHBoxLayout()
        fft_layout.addWidget(self.fft_radio1)
        fft_layout.addWidget(self.fft_radio2)
        fft_layout.addWidget(QtWidgets.QLabel("Nr. of samples:"))
        fft_layout.addWidget(self.fft_spinbox)
        fft_group.setLayout(fft_layout)
        fft_group.setFixedHeight(70)

        # FPGA controls
        # Left/Right Volume
        self.volume_left_slider.setMinimum(0)
        self.volume_left_slider.setMaximum(200)
        self.volume_left_slider.setValue(100)
        self.volume_left_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.volume_left_slider.setTickInterval(
            int((self.volume_left_slider.maximum() - self.volume_left_slider.minimum()) / 10))
        self.volume_left_slider.valueChanged.connect(self.on_volume_left_changed)

        self.volume_left_label.setFixedWidth(45)
        self.volume_left_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)

        volume_left_layout = QtWidgets.QHBoxLayout()
        volume_left_layout.addWidget(self.volume_left_label)
        volume_left_layout.addWidget(self.volume_left_slider)
        self.on_volume_left_changed(100)

        self.volume_right_slider.setMinimum(0)
        self.volume_right_slider.setMaximum(200)
        self.volume_right_slider.setValue(100)
        self.volume_right_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.volume_right_slider.setTickInterval(
            int((self.volume_right_slider.maximum() - self.volume_right_slider.minimum()) / 10))
        self.volume_right_slider.valueChanged.connect(self.on_volume_right_changed)

        self.volume_right_label.setFixedWidth(45)
        self.volume_right_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_volume_right_changed(100)

        volume_right_layout = QtWidgets.QHBoxLayout()
        volume_right_layout.addWidget(self.volume_right_label)
        volume_right_layout.addWidget(self.volume_right_slider)

        volume_group = QtWidgets.QGroupBox("Left / Right volume")
        volume_layout = QtWidgets.QHBoxLayout()
        volume_layout.addLayout(volume_left_layout)
        volume_layout.addLayout(volume_right_layout)
        volume_group.setLayout(volume_layout)
        volume_group.setMaximumHeight(100)

        # Left/Right Delay
        self.delay_left_slider.setMinimum(0)
        self.delay_left_slider.setMaximum(131070)
        self.delay_left_slider.setValue(0)
        self.delay_left_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.delay_left_slider.setTickInterval(
            int((self.delay_left_slider.maximum() - self.delay_left_slider.minimum()) / 10))
        self.delay_left_slider.valueChanged.connect(self.on_delay_left_changed)

        self.delay_left_label.setFixedWidth(45)
        self.delay_left_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)

        delay_left_layout = QtWidgets.QHBoxLayout()
        delay_left_layout.addWidget(self.delay_left_label)
        delay_left_layout.addWidget(self.delay_left_slider)
        self.on_delay_left_changed(0)

        self.delay_right_slider.setMinimum(0)
        self.delay_right_slider.setMaximum(131070)
        self.delay_right_slider.setValue(0)
        self.delay_right_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.delay_right_slider.setTickInterval(
            int((self.delay_right_slider.maximum() - self.delay_right_slider.minimum()) / 10))
        self.delay_right_slider.valueChanged.connect(self.on_delay_right_changed)

        self.delay_right_label.setFixedWidth(45)
        self.delay_right_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_delay_right_changed(0)

        delay_right_layout = QtWidgets.QHBoxLayout()
        delay_right_layout.addWidget(self.delay_right_label)
        delay_right_layout.addWidget(self.delay_right_slider)

        delay_group = QtWidgets.QGroupBox("Left / Right delay")
        delay_layout = QtWidgets.QHBoxLayout()
        delay_layout.addLayout(delay_left_layout)
        delay_layout.addLayout(delay_right_layout)
        delay_group.setLayout(delay_layout)
        delay_group.setMaximumHeight(100)

        # Mixer
        self.mixer_radio1.setChecked(True)
        self.mixer_group = QtWidgets.QButtonGroup(self)
        self.mixer_group.addButton(self.mixer_radio1, 0)
        self.mixer_group.addButton(self.mixer_radio2, 1)
        self.mixer_group.addButton(self.mixer_radio3, 2)
        self.mixer_group.addButton(self.mixer_radio4, 3)
        self.mixer_group.addButton(self.mixer_radio5, 4)
        self.mixer_group.addButton(self.mixer_radio6, 5)
        self.mixer_group.addButton(self.mixer_radio7, 6)
        self.mixer_group.buttonClicked.connect(self.on_mixer_selected)

        self.lpf_spinbox.setRange(1, 48000)
        self.lpf_spinbox.setValue(2000)
        self.lpf_spinbox.valueChanged.connect(self.on_frequencies_changed)

        self.hpf_spinbox.setRange(1, 48000)
        self.hpf_spinbox.setValue(2000)
        self.hpf_spinbox.valueChanged.connect(self.on_frequencies_changed)

        self.bpf_low_spinbox.setRange(1, 48000)
        self.bpf_low_spinbox.setValue(2000)
        self.bpf_low_spinbox.valueChanged.connect(self.on_frequencies_changed)

        self.bpf_high_spinbox.setRange(1, 48000)
        self.bpf_high_spinbox.setValue(5000)
        self.bpf_high_spinbox.valueChanged.connect(self.on_frequencies_changed)

        self.bsf_spinbox.setRange(1, 48000)
        self.bsf_spinbox.setValue(2000)
        self.bsf_spinbox.valueChanged.connect(self.on_frequencies_changed)

        label = QtWidgets.QLabel("Frequency:")
        label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)

        lpf_layout = QtWidgets.QHBoxLayout()
        lpf_layout.addWidget(self.mixer_radio2)
        lpf_layout.addWidget(label)
        lpf_layout.addWidget(self.lpf_spinbox)

        label = QtWidgets.QLabel("Frequency:")
        label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)

        hpf_layout = QtWidgets.QHBoxLayout()
        hpf_layout.addWidget(self.mixer_radio3)
        hpf_layout.addWidget(label)
        hpf_layout.addWidget(self.hpf_spinbox)

        label = QtWidgets.QLabel("Low / High Freq:")
        label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)

        bpf_layout = QtWidgets.QHBoxLayout()
        bpf_layout.addWidget(self.mixer_radio4)
        bpf_layout.addWidget(label)
        bpf_layout.addWidget(self.bpf_low_spinbox)
        bpf_layout.addWidget(self.bpf_high_spinbox)

        label = QtWidgets.QLabel("Frequency:")
        label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)

        bsf_layout = QtWidgets.QHBoxLayout()
        bsf_layout.addWidget(self.mixer_radio5)
        bsf_layout.addWidget(label)
        bsf_layout.addWidget(self.bsf_spinbox)

        self.distortion_slider.setInvertedAppearance(True)
        self.distortion_slider.setInvertedControls(True)
        self.distortion_slider.setMinimum(0)
        self.distortion_slider.setMaximum(1000)
        self.distortion_slider.setValue(1000)
        self.distortion_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.distortion_slider.setTickInterval(
            int((self.distortion_slider.maximum() - self.distortion_slider.minimum()) / 10))
        self.distortion_slider.valueChanged.connect(self.on_distortion_changed)

        self.distortion_label.setFixedWidth(65)
        self.distortion_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_distortion_changed(1000)

        distortion_layout = QtWidgets.QHBoxLayout()
        distortion_layout.addWidget(self.mixer_radio6)
        distortion_layout.addWidget(self.distortion_label)
        distortion_layout.addWidget(self.distortion_slider)

        self.tremolo_slider.setMinimum(0)
        self.tremolo_slider.setMaximum(24000)
        self.tremolo_slider.setValue(5)
        self.tremolo_slider.setTickPosition(QtWidgets.QSlider.TickPosition.TicksBelow)
        self.tremolo_slider.setTickInterval(
            int((self.tremolo_slider.maximum() - self.tremolo_slider.minimum()) / 10))
        self.tremolo_slider.valueChanged.connect(self.on_tremolo_changed)

        self.tremolo_label.setFixedWidth(65)
        self.tremolo_label.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignRight | QtCore.Qt.AlignmentFlag.AlignVCenter)
        self.on_tremolo_changed(5)

        tremolo_layout = QtWidgets.QHBoxLayout()
        tremolo_layout.addWidget(self.mixer_radio7)
        tremolo_layout.addWidget(self.tremolo_label)
        tremolo_layout.addWidget(self.tremolo_slider)

        mixer_group = QtWidgets.QGroupBox("Mixer")
        mixer_layout = QtWidgets.QVBoxLayout()
        mixer_layout.setSpacing(10)
        mixer_layout.addWidget(self.mixer_radio1)
        mixer_layout.addLayout(lpf_layout)
        mixer_layout.addLayout(hpf_layout)
        mixer_layout.addLayout(bpf_layout)
        mixer_layout.addLayout(bsf_layout)
        mixer_layout.addLayout(distortion_layout)
        mixer_layout.addLayout(tremolo_layout)
        mixer_group.setLayout(mixer_layout)

        # Combine
        fpga_control_group = QtWidgets.QGroupBox("FPGA Control")
        fpga_control_layout = QtWidgets.QVBoxLayout()
        fpga_control_layout.addWidget(volume_group)
        fpga_control_layout.addWidget(delay_group)
        fpga_control_layout.addWidget(mixer_group)
        fpga_control_group.setLayout(fpga_control_layout)

        controls_layout.addWidget(time_group)
        controls_layout.addWidget(amplitude_group)
        controls_layout.addWidget(fft_group)
        controls_layout.addWidget(fpga_control_group)
        return controls_layout

    def on_timescale_changed(self, value):
        min_time = 0.0001  # seconds
        max_time = BUFFER_SECONDS  # seconds

        # linear slider -> logarithmic time_step
        fraction = value / self.time_step_slider.maximum()  # 0 … 1
        log_value = min_time * (max_time / min_time) ** fraction

        self.time_step = log_value
        if log_value < 0.5e-3:
            self.time_step_label.setText(f"{log_value * 1e6:.1f} µs")
        elif log_value < 0.5:
            self.time_step_label.setText(f"{log_value * 1e3:.2f} ms")
        else:
            self.time_step_label.setText(f"{log_value:.2f} s")

    def on_amplitude_step_changed(self, value):
        self.amplitude = 10 / value
        self.amplitude_step_label.setText(f"{1000 / value:.1f} %")

        self.on_amplitude_offset_changed(self.amplitude_offset_slider.value())

    def on_amplitude_offset_changed(self, value):
        real_value = value

        self.amplitude_offset = int(real_value)
        self.amplitude_offset_label.setText(f"{real_value:.1f} %")

    def on_volume_left_changed(self, value):
        reg_value = math.floor((value / 200) * (2 ** 31))
        self.reg_block.set("vol_left", reg_value - 1)

        self.volume_left_label.setText(f"{value} %")

    def on_volume_right_changed(self, value):
        reg_value = math.floor((value / 200) * (2 ** 31))
        self.reg_block.set("vol_right", reg_value - 1)

        self.volume_right_label.setText(f"{value} %")

    def on_delay_left_changed(self, value):
        self.reg_block.set("delay_left", value)
        self.delay_left_label.setText(f"{value * (1.0 / 48000):.2f} s")

    def on_delay_right_changed(self, value):
        self.reg_block.set("delay_right", value)
        self.delay_right_label.setText(f"{value * (1.0 / 48000):.2f} s")

    def on_distortion_changed(self, value):
        log_val = (2 ** 23 - 1) ** (value / 1000)

        self.reg_block.set("distortion", int(log_val))
        self.distortion_label.setText(f"{log_val / (2 ** 23 - 1):.6f}")

    def on_tremolo_changed(self, value):
        freq = 24000 ** (value / 24000)
        reg_freq = math.floor((1024 * int(freq) / 48000) * (2 ** 16))

        self.reg_block.set("tremolo", reg_freq)
        self.tremolo_label.setText(f"{int(freq)} Hz")

    def on_frequencies_changed(self, value):
        lpf_val = math.floor((1 - math.e ** (-2 * math.pi * (self.lpf_spinbox.value() / 48000))) * (2 ** 31))
        self.reg_block.set("lpf", lpf_val)

        k = math.tan(math.pi * (self.hpf_spinbox.value() / 48000))
        hpf_val = math.floor(((1 - k) / (1 + k)) * (2 ** 31))
        self.reg_block.set("hpf", hpf_val)

        bpf_low_val = math.floor((1 - math.e ** (-2 * math.pi * (self.bpf_low_spinbox.value() / 48000))) * (2 ** 31))
        self.reg_block.set("bpf_low", bpf_low_val)

        k = math.tan(math.pi * (self.bpf_high_spinbox.value() / 48000))
        bpf_high_val = math.floor(((1 - k) / (1 + k)) * (2 ** 31))
        self.reg_block.set("bpf_high", bpf_high_val)

        bsf_val = math.floor((2 * math.cos(2 * math.pi * (self.bsf_spinbox.value() / 48000))) * (2 ** 30))
        self.reg_block.set("bsf", bsf_val)

    def on_mixer_selected(self, value):
        id = self.mixer_group.id(value)
        self.reg_block.set("mixer", id)

    # FFT average helpers
    def _avg_hold_push(self, P_left: np.ndarray, P_right: np.ndarray):
        avg_frames = self.fft_spinbox.value()

        if (
                self._avg_buf_left is None
                or self._avg_buf_left.shape[0] != avg_frames
                or self._avg_buf_left.shape[1] != P_left.shape[0]
        ):
            self._avg_buf_left = np.zeros((avg_frames, P_left.shape[0]), dtype=np.float64)
            self._avg_buf_right = np.zeros((avg_frames, P_right.shape[0]), dtype=np.float64)
            self._avg_idx = 0
            self._avg_count = 0

        self._avg_buf_left[self._avg_idx, :] = P_left
        self._avg_buf_right[self._avg_idx, :] = P_right
        self._avg_idx = (self._avg_idx + 1) % avg_frames
        self._avg_count = min(self._avg_count + 1, avg_frames)

    def _avg_hold_get(self) -> tuple[np.ndarray, np.ndarray]:
        n = self._avg_count

        if self.fft_radio1.isChecked():
            Pl = self._avg_buf_left[:n, :].mean(axis=0)
            Pr = self._avg_buf_right[:n, :].mean(axis=0)
        else:
            Pl = self._avg_buf_left[:n, :].max(axis=0)
            Pr = self._avg_buf_right[:n, :].max(axis=0)

        return Pl, Pr
