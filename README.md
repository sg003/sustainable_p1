# Energy Measurement of Chrome Profiles using EnergiBridge

This project measures energy consumption while **Google Chrome** (using real Chrome profiles with extensions such as ad blockers) automatically visits news websites and scrolls for a fixed duration.  
Energy measurements are collected using **EnergiBridge** and stored as CSV files.

---

## Overview

For each specified Chrome profile (e.g., *Profile 1* and *Profile 2*), the system:

1. Launches Google Chrome with the chosen profile
2. Enables Chrome DevTools remote debugging
3. Runs a Python script that:
   - Opens a predefined list of news websites
   - Scrolls down the page periodically for a fixed duration
4. EnergiBridge measures the energy consumption during the scrolling workload
5. Outputs one CSV file per profile in `energibridge_outputs/`

This setup enables controlled comparison of energy usage between different Chrome configurations (e.g., ad blocker enabled vs. disabled).

---

## Repository Contents

- **`measure_profiles.sh`**  
  Shell script that orchestrates the experiment. It launches Chrome per profile, runs EnergiBridge, and triggers the scrolling workload.

- **`scroll_chrome.py`**  
  Python script that connects to Chrome via the DevTools protocol to open pages and simulate scrolling.

- **`energibridge_outputs/`**  
  Directory containing CSV files with energy measurement results (a sample CSV may be included for reference).

---

## Requirements

### 1. Google Chrome
Google Chrome must be installed, since real Chrome profiles and extensions are required.

Verify:
```bash
which google-chrome
google-chrome --version

## 2. Python

The experiment requires Python 3 and the following packages:

- `requests`
- `websocket-client`

It is recommended to use a virtual environment to avoid polluting the system Python installation.

```bash
python3 -m venv venv
source venv/bin/activate
pip install requests websocket-client

## 3. EnergiBridge

EnergiBridge is used to measure energy consumption while the scrolling workload is running.

### Build EnergiBridge

Clone the EnergiBridge repository and build it according to the machine.