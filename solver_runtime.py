import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("metrics_table.csv")

runtime = {
    "i2c":0.038,
    "uart_full":0.008,
    "sdram":0.024,
    "sha3":0.25,
    "generic_fifo_lfsr":1.255,
    "up8_minimal":0.04
}

df["runtime"] = df["Design"].map(runtime)

plt.scatter(df["CHI_NORM"], df["runtime"])

for i,row in df.iterrows():
    plt.text(row["CHI_NORM"], row["runtime"], row["Design"])

plt.xlabel("Normalized Complexity χ")
plt.ylabel("Solver Runtime (ASL)")
plt.title("Complexity vs Solver Runtime")

plt.show()