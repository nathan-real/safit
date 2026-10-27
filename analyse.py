import numpy as np

t = np.loadtxt("pts.txt", encoding="utf-16")
t = np.sort(t)
d = np.diff(t)
print("images :", len(t), "| durée :", round(t[-1] - t[0], 3), "s")
print("fps moyen :", round((len(t) - 1) / (t[-1] - t[0]), 2))
print("intervalle médian :", round(np.median(d) * 1000, 3), "ms (idéal : 4.167 ms)")
print("fps médian :", round(1 / np.median(d), 1))
print("intervalles > 6 ms :", int((d > 0.006).sum()), "sur", len(d))
print(
    "plus grand trou :",
    round(d.max() * 1000, 1),
    "ms à t =",
    round(t[d.argmax()], 2),
    "s",
)
trous = t[:-1][d > 0.006]
print("trous à t =", np.round(trous, 2))
print("images manquantes ~", int(round(((d[d > 0.006] / 0.0041667) - 1).sum())))