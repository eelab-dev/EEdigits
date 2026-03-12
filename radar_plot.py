import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

df = pd.read_csv("metrics_table.csv")
features = ["D_A", "D_M", "W_norm", "I_C", "D_R_norm"]

labels = np.array(features)
angles = np.linspace(0, 2*np.pi, len(labels), endpoint=False)

fig = plt.figure(figsize=(8, 8))
ax = fig.add_subplot(111, polar=True)

for _, row in df.iterrows():
    values = row[features].values.astype(float)
    values = np.concatenate((values, [values[0]]))
    ang = np.concatenate((angles, [angles[0]]))
    ax.plot(ang, values, linewidth=2, label=row["Design"])
    ax.fill(ang, values, alpha=0.10)

ax.set_thetagrids(angles * 180 / np.pi, labels, fontsize=12)
ax.tick_params(axis='y', labelsize=10)
ax.set_title("Structural Complexity Radar", fontsize=16, pad=20)
ax.legend(loc="upper left", bbox_to_anchor=(1.05, 1.05), fontsize=11)
plt.tight_layout()
#plt.savefig("structural_complexity_radar.png", dpi=300, bbox_inches="tight")
plt.show()