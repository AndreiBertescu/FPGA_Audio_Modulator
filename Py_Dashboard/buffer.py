import threading
import numpy as np


class RegBlock:
    def __init__(self):
        self.regs = [
            0x00000000,  # Mixer select
            0x3FFF_FFFF,  # Volume left
            0x3FFF_FFFF,  # Volume right
            0x1d7b_9a90,  # LPF
            0x6237_c54f,  # HPF
            0x1d7b_9a90,  # BPF low
            0x6237_c54f,  # BPF high
            0x7ba3_751d,  # BSF
            11,  # Distortion
            0x00000576,  # Tremolo
            0,  # Delay left
            0  # Delay right
        ]
        self.lock = threading.Lock()

        # Optional: map names → indices
        self.names = {
            "mixer": 0,
            "vol_left": 1,
            "vol_right": 2,
            "lpf": 3,
            "hpf": 4,
            "bpf_low": 5,
            "bpf_high": 6,
            "bsf": 7,
            "distortion": 8,
            "tremolo": 9,
            "delay_left": 10,
            "delay_right": 11,
        }

    def set(self, key, value: int):
        with self.lock:
            if isinstance(key, str):
                idx = self.names[key]
            else:
                idx = key
            self.regs[idx] = value & 0xFFFFFFFF

    def get(self, key):
        with self.lock:
            if isinstance(key, str):
                idx = self.names[key]
            else:
                idx = key
            return self.regs[idx]

    def dump(self):
        with self.lock:
            return self.regs.copy()


class RingBuffer:
    def __init__(self, size):
        self.size = int(size)
        self.lock = threading.Lock()
        self.buf = np.zeros(self.size, dtype=np.int32)
        self.write_ptr = 0

        # FFT cache: key -> (write_ptr, result)
        # Window cache: length -> window ndarray
        self._fft_cache = {}
        self._window_cache = {}

    def write(self, data: np.ndarray):
        length = data.shape[0]

        if length == 0:
            return

        with self.lock:
            end = self.write_ptr + length

            if end <= self.size:
                self.buf[self.write_ptr:end] = data
            else:
                first = self.size - self.write_ptr
                self.buf[self.write_ptr:] = data[:first]
                self.buf[: end % self.size] = data[first:]

            self.write_ptr = end % self.size

        # Invalidate FFT cache after any write
        self._fft_cache.clear()

    def read(self, nr_samples: int) -> np.ndarray:
        corrected_nr_samples = self.size if nr_samples > self.size else nr_samples

        with self.lock:
            end = self.write_ptr
            start = (end - corrected_nr_samples) % self.size

            if start < end:
                return self.buf[start:end].copy()
            else:
                return np.concatenate((self.buf[start:], self.buf[:end])).copy()

    # FFT methods
    def get_fft(self, n_fft: int, window: str = "hann") -> np.ndarray:
        padded_len = 1 << (int(n_fft - 1).bit_length())

        # Use cache if nothing changed for this configuration
        cache_key = (n_fft, window)
        with self.lock:
            wp = self.write_ptr
        cached = self._fft_cache.get(cache_key)
        if cached is not None:
            cached_wp, cached_fft = cached
            if cached_wp == wp:
                return cached_fft.copy()

        # Snapshot most recent n_fft samples (outside further lock use)
        x = self.read(n_fft).astype(np.float64, copy=False)

        # Scale-compensate window to preserve overall energy roughly
        w = self._get_window(len(x), window)
        if w is not None:
            x = x * w

        # Zero-pad if needed
        if padded_len > len(x):
            xz = np.zeros(padded_len, dtype=x.dtype)
            xz[: len(x)] = x
            x = xz
        elif padded_len < len(x):
            x = x[-padded_len:]

        # Compute FFT
        X = np.fft.rfft(x)

        # Cache using the write_ptr at snapshot time
        self._fft_cache[cache_key] = (wp, X.copy())
        return X

    def get_freq_axis(self, n_fft: int):
        padded_len = (1 << (int(n_fft - 1).bit_length()))

        return np.fft.rfftfreq(padded_len, d=1.0 / 48000)

    def _get_window(self, length: int, kind: str):
        key = (length, kind)
        if key in self._window_cache:
            return self._window_cache[key]

        if kind == "hann":
            w = np.hanning(length).astype(np.float64)
        elif kind == "hamming":
            w = np.hamming(length).astype(np.float64)
        else:  # kind == "blackman"
            w = np.blackman(length).astype(np.float64)

        self._window_cache[key] = w
        return w
