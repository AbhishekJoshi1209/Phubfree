# Phubb-Free

**Phubb-Free** is a privacy-first, on-device AI system designed to detect and reduce "phubbing" (phone-snubbing) during real-life social interactions. It passively monitors phone usage and uses behavioral science to deliver gentle nudges when a user is likely ignoring someone nearby in favor of their phone.

### Key Features
* **100% Private (On-Device):** All data processing and AI personalization happens directly on the user's phone. No behavioral data is ever sent to the cloud.
* **Personalized AI:** It doesn't use a strict, one-size-fits-all rule. It learns what "normal" phone usage looks like for *that specific user* and adapts over time.
* **Lightweight TFLite Models:** Uses custom exported TensorFlow Lite models (under 1KB) to run inferences continuously without draining the smartphone battery.

---

## The Core Challenge: The Proxy Label

"Phubbing" is a subjective social construct. Since we can't directly measure if someone feels snubbed, we built a **proxy label**. 

We define a potential phubbing moment as: *Any significant phone interaction (like unlocking the screen or switching apps) that occurs while another person's Bluetooth/Wi-Fi signal is detected nearby.*

> **Note:** The baseline model evaluates against this constructed proxy label, not absolute ground-truth phubbing. The goal of the baseline is to find the rhythms of phone usage, which are later personalized on-device.

---

## Project Architecture

### Stage 1: Data Engineering (Completed)
We transformed three massive, raw smartphone telemetry datasets (App Usage, Notifications, Proximity) into optimized `.parquet` files. We engineered rolling 1-hour window statistics (e.g., `unlock_freq_1h`, `notif_resp_latency_mean_1h`) and aligned asynchronous events onto a unified timeline.

### Stage 2: AI Model Training (Completed)
We trained a baseline model using a `GroupShuffleSplit` (grouped by user) to prevent temporal data leakage. We evaluated both Logistic Regression and Gradient-Boosted Trees (HistGBT). 

*   **Selected Model:** Logistic Regression
*   **Performance:** F1 = 0.5727, AUC-ROC = 0.5900
*   **Custom TFLite Export:** We engineered a pure-Python TFLite exporter that bypasses TensorFlow C++ DLL issues (common on Windows) by directly constructing the TFLite flatbuffer from the `schema_py_generated.py`.

### Stage 3: Mobile App Interface (Upcoming)
A cross-platform Flutter application that loads the `.tflite` model to run offline inferences, securely collects background sensor data, and provides a beautiful user dashboard.

### Stage 4: On-Device Personalization (Upcoming)
The application will constantly monitor the user's specific daily routines. Using federated learning concepts, the app will mathematically adjust its internal threshold for what constitutes an "interruption" *for that specific user*, entirely locally.

---

## Getting Started

### Prerequisites

Ensure you have Python 3.12+ installed. 

```bash
# Clone the repository
git clone https://github.com/your-username/Phubfree.git
cd Phubfree

# Install dependencies
pip install pandas scikit-learn pyarrow joblib matplotlib seaborn flatbuffers
```
*(Note: Full TensorFlow is not strictly required for exporting the Logistic Regression model due to the custom pure-Python exporter, but can be installed if evaluating GBT distillation).*

### Running the Pipeline

Stage 1 data is already pre-processed and saved in `data/features_labeled.parquet`. To run the Stage 2 training and export pipeline:

```bash
python -m phubb_free.run_stage2
```

**Pipeline execution steps:**
1. Loads the feature parquet file.
2. Scales features and performs a strict user-level train/test split.
3. Trains Logistic Regression and GBT models.
4. Generates evaluation plots (`models/roc_curve.png`, `models/confusion_matrix.png`, etc.).
5. Executes the custom pure-Python TFLite export, saving `models/phubbing_detector.tflite`.

---

## Output Artifacts

After running the pipeline, check the `models/` directory for:
*   `best_model.joblib`: The scikit-learn model weights.
*   `scaler.joblib`: The fitted feature scaler.
*   `phubbing_detector.tflite`: The compressed, ready-to-deploy mobile model.
*   `evaluation_report.txt`: Full classification metrics.
*   `*.png`: Visualizations for ROC curves, confusion matrices, and feature importance.
