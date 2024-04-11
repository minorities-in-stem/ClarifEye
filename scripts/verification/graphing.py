import json
import matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.lines import Line2D
from matplotlib.patches import Patch


def plot_scene_info(scene, t0=None, tN=None, xlim=None, ylim=None):
    plt.figure()

    depths = {}
    gt_times = {}

    for obj_cls in scene["data"]:
        tmin = float('inf')
        tmax = float('-inf')
        for i, trial in enumerate(scene['trials']):
            t_depth = []
            v_depth = []
            for j, report in enumerate(trial):
                if obj_cls in report["detections"]:
                    t = report["rel_timestamp"]
                    tmin, tmax = min(t, tmin), max(t, tmax)
                    t_depth.append(t)

                    v_depth.append(report["detections"][obj_cls]["depth"])

            if obj_cls not in depths:
                depths[obj_cls] = []
            depths[obj_cls].append((i+1, t_depth, v_depth))
            
            if t0 is None or tN is None:
                t0, tN = tmin, tmax
            gt_times[obj_cls] = [t0, tN]

    COLORS = ["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple", "tab:brown"]
    LINESTYLES = ["dashed", "dotted", "dashdot"]
    GT_LINESTYLE = "solid"
    
    for obj_cls, color in zip(depths, COLORS):
        for (i_trial, x, y), ls in zip(depths[obj_cls], LINESTYLES):
            plt.plot(x, y, color=color, linestyle=ls)

        plt.plot(gt_times[obj_cls], scene['data'][obj_cls], linestyle=GT_LINESTYLE)

    legend_elements = []
    for obj_cls, color in zip(depths, COLORS):
        legend_elements.append(Line2D([0], [0], marker='o', color='w', label=obj_cls, markerfacecolor=color, markersize=10))
    for i, ls in enumerate(LINESTYLES):
        legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=ls, lw=2, label=f'Trial {i+1}'))
    legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=GT_LINESTYLE, lw=2, label='Ground Truth'))

    plt.title(scene['description'])
    plt.xlabel('Time (s)')
    plt.ylabel('Depth (m)')
    plt.legend(handles=legend_elements)
    plt.show()


def main(folder):
    with open(folder / f"all.json", "r") as f:
        scenes = json.load(f)

    for scene in scenes:
        kwargs = scene.get('kwargs', {})
        plot_scene_info(scene, **kwargs)


if __name__ == "__main__":
    folder = Path("./verification-data")
    main(folder)
