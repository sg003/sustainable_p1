import os
import glob
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import shapiro, ttest_ind, mannwhitneyu

"""
README of this file.

What is currently being measured is the Package Energy which is the energy from the CPU

The current results are:

Shapiro-Wilk test for Profile1
p-value = 0.10187 → Normal (assumed)

Shapiro-Wilk test for Profile2
p-value = 0.02289 → Not normal

The results are not normal for profile 2, so we need to use a Mann-Whitney U test that doesn't need the normality assumption
We should be able to explain why profile 2 is not normal

===== Statistical Test =====
Using Mann-Whitney U test
p-value = 0.00000 → Statistically significant difference

===== Effect Size =====
Mean Profile1 = 591.814 J
Mean Profile2 = 415.513 J
Mean Difference = -176.301 J
Percent Change = -29.79%
Median Difference = -174.674 J



"""

# ============================
# CONFIG
# ============================

DATA_FOLDER = "../energibridge_outputs"
ENERGY_COLUMN = "PACKAGE_ENERGY (J)"
ALPHA = 0.05


# ============================
# STEP 1: LOAD + EXTRACT ENERGY
# ============================

def extract_total_energy(filepath):
    df = pd.read_csv(filepath)

    if ENERGY_COLUMN not in df.columns:
        raise ValueError(f"{ENERGY_COLUMN} not found in {filepath}")

    start = df[ENERGY_COLUMN].iloc[0]
    end = df[ENERGY_COLUMN].iloc[-1]

    return end - start


def load_data():
    profile1 = []
    profile2 = []

    files = glob.glob(os.path.join(DATA_FOLDER, "*.csv"))

    for file in files:
        energy = extract_total_energy(file)

        if "profile1" in file:
            profile1.append(energy)
        elif "profile2" in file:
            profile2.append(energy)

    return np.array(profile1), np.array(profile2)


# ============================
# STEP 2: EXPLORATORY ANALYSIS
# ============================

def exploratory_plots(sample1, sample2):
    plt.figure()
    plt.violinplot([sample1, sample2])
    plt.xticks([1, 2], ["Profile 1", "Profile 2"])
    plt.ylabel("Total Energy (J)")
    plt.title("Violin Plot - Energy Consumption")
    plt.show()

    plt.figure()
    plt.boxplot([sample1, sample2])
    plt.xticks([1, 2], ["Profile 1", "Profile 2"])
    plt.ylabel("Total Energy (J)")
    plt.title("Box Plot - Energy Consumption")
    plt.show()

    plt.figure()
    plt.hist(sample1, alpha=0.5)
    plt.hist(sample2, alpha=0.5)
    plt.title("Histogram - Energy Distribution")
    plt.show()


# ============================
# STEP 3: NORMALITY CHECK
# ============================

def check_normality(sample, label):
    stat, p = shapiro(sample)
    print(f"\nShapiro-Wilk test for {label}")
    print(f"p-value = {p:.5f}")

    if p < ALPHA:
        print("→ Not normal")
        return False
    else:
        print("→ Normal (assumed)")
        return True


# ============================
# STEP 4: STATISTICAL TEST
# ============================

def statistical_test(sample1, sample2, normal1, normal2):

    print("\n===== Statistical Test =====")

    if normal1 and normal2:
        print("Using Welch's t-test")
        stat, p = ttest_ind(sample1, sample2, equal_var=False)
        test_used = "Welch t-test"
    else:
        print("Using Mann-Whitney U test")
        stat, p = mannwhitneyu(sample1, sample2, alternative='two-sided')
        test_used = "Mann-Whitney U"

    print(f"p-value = {p:.5f}")

    if p < ALPHA:
        print("→ Statistically significant difference")
    else:
        print("→ No statistically significant difference")

    return test_used, p


# ============================
# STEP 5: EFFECT SIZE
# ============================

def effect_size(sample1, sample2, normal1, normal2):
    print("\n===== Effect Size =====")

    mean1 = np.mean(sample1)
    mean2 = np.mean(sample2)
    diff = mean2 - mean1
    percent_change = (diff / mean1) * 100

    print(f"Mean Profile1 = {mean1:.3f} J")
    print(f"Mean Profile2 = {mean2:.3f} J")
    print(f"Mean Difference = {diff:.3f} J")
    print(f"Percent Change = {percent_change:.2f}%")

    if normal1 and normal2:
        pooled_std = np.sqrt((np.std(sample1, ddof=1)**2 +
                              np.std(sample2, ddof=1)**2) / 2)
        cohens_d = diff / pooled_std
        print(f"Cohen's d = {cohens_d:.3f}")
    else:
        median1 = np.median(sample1)
        median2 = np.median(sample2)
        print(f"Median Difference = {median2 - median1:.3f} J")


# ============================
# MAIN PIPELINE
# ============================

def main():

    profile1, profile2 = load_data()

    print(f"Profile1 runs: {len(profile1)}")
    print(f"Profile2 runs: {len(profile2)}")

    exploratory_plots(profile1, profile2)

    normal1 = check_normality(profile1, "Profile1")
    normal2 = check_normality(profile2, "Profile2")

    test_used, p_value = statistical_test(profile1, profile2, normal1, normal2)

    effect_size(profile1, profile2, normal1, normal2)


if __name__ == "__main__":
    main()