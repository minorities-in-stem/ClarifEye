import json
import matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.lines import Line2D
from matplotlib.patches import Patch


LINESTYLES = ["dashed", "dotted", "dashdot"]
MARKERS = ["o", "v", "D"]
GT_LINESTYLE = "solid"
COLORS = ["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple", "tab:brown"]


def plot_scene_depth(scene, t0=None, tN=None, offset={}, max_time=None, min_time=None, ylim=None, xlim=None, plot_all=False, save_fig=None):
    plt.figure()

    depths = {}
    gt_times = {}

    obj_classes = set()
    if plot_all:
        for trial in scene['trials']:
            for report in trial:
                obj_classes.update(report["detections"].keys())
    obj_classes.update(scene["data"].keys())
    obj_classes = sorted(list(obj_classes))

    tmin = float('inf')
    tmax = float('-inf')

    for obj_cls in obj_classes:
        for i, trial in enumerate(scene['trials']):
            t_depth = []
            v_depth = []
            for j, report in enumerate(trial):
                if obj_cls in report["detections"]:
                    t = report["rel_timestamp"]
                    if min_time is not None and t < min_time:
                        continue
                    if max_time is not None and t > max_time:
                        continue
                    tmin, tmax = min(t, tmin), max(t, tmax)
                    t_depth.append(t)
                    v_depth.append(report["detections"][obj_cls]["depth"])

            if obj_cls not in depths:
                depths[obj_cls] = []
            depths[obj_cls].append((i+1, t_depth, v_depth))

    if t0 is None or tN is None:
        t0, tN = tmin, tmax

    for obj_cls in obj_classes:
        if obj_cls in offset:
            t0_off, tN_off = offset[obj_cls]
            gt_times[obj_cls] = [t0+t0_off, tN+tN_off]
        else:
            gt_times[obj_cls] = [t0, tN]
    
    for obj_cls, color in zip(obj_classes, COLORS):
        if obj_cls in depths:
            for (i, x, y), ls in zip(depths[obj_cls], LINESTYLES):
                plt.plot(x, y, color=color, linestyle=ls)

        if obj_cls in gt_times and obj_cls in scene['data']:
            plt.plot(gt_times[obj_cls], scene['data'][obj_cls], linestyle=GT_LINESTYLE, lw=5, alpha=0.7, color=color)

    legend_elements = []
    for obj_cls, color in zip(obj_classes, COLORS):
        legend_elements.append(Line2D([0], [0], marker='o', color='w', label=obj_cls, markerfacecolor=color, markersize=10))
    for i, ls in enumerate(LINESTYLES):
        legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=ls, lw=2, label=f'Trial {i+1}'))
    legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=GT_LINESTYLE, lw=5, alpha=0.7, label='Ground Truth'))

    plt.title("Depth: " + scene['description'])
    plt.xlabel('Time (s)')
    plt.ylabel('Depth (m)')
    if ylim is not None:
        plt.ylim(ylim)
    if xlim is not None:
        plt.xlim(xlim)
    plt.legend(handles=legend_elements)

    if save_fig is not None:
        plt.savefig(save_fig)
    else:
        plt.show()


def plot_scene_score(scene, t0=None, tN=None, i_trial=None, ylim=None, xlim=None, plot_per_interval=True, save_fig=None, **kwargs):
    plt.figure()

    max_scores = {}

    obj_classes = set()
    for trial in scene['trials']:
        for report in trial:
            obj_classes.update(report["detections"].keys())
    obj_classes.update(scene["data"].keys())
    obj_classes = sorted(list(obj_classes))

    for obj_cls in obj_classes:
        for i, trial in enumerate(scene['trials']):
            t_max_score = []
            v_max_score = []

            for j, report in enumerate(trial):
                if i_trial is not None and i_trial != j:
                    continue

                t = report["rel_timestamp"]
                max_score = float('-inf')
                for obj_cls, d in report["detections"].items():
                    if d["score"] > max_score:
                        max_score = d["score"]
                        max_obj_cls = obj_cls

                t_max_score.append(t)
                v_max_score.append(max_score)
            
            if max_obj_cls not in max_scores:
                max_scores[max_obj_cls] = []
            max_scores[max_obj_cls].append((i, t_max_score, v_max_score))
                
    if plot_per_interval:
        int_scores = {}
        for obj_cls in obj_classes:
            for i, trial in enumerate(scene['trials']):
                t_int_score = []
                v_int_score = []

                for j, report in enumerate(trial):
                    if i_trial is not None and i_trial != j:
                        continue
                    for k, per_interval in enumerate(report["per_interval"]):
                        if obj_cls in per_interval["detections"]:
                            t = per_interval["rel_timestamp"]
                            t_int_score.append(t)
                            v_int_score.append(per_interval["detections"][obj_cls]["score"])

                if obj_cls not in int_scores:
                    int_scores[obj_cls] = []
                int_scores[obj_cls].append((i+1, t_int_score, v_int_score))
    else:
        rep_scores = {}
        for obj_cls in obj_classes:
            for i, trial in enumerate(scene['trials']):
                t_rep_score = []
                v_rep_score = []

                for j, report in enumerate(trial):
                    if i_trial is not None and i_trial != j:
                        continue
                    if obj_cls in report["detections"]:
                        t = report["rel_timestamp"]
                        t_rep_score.append(t)
                        v_rep_score.append(report["detections"][obj_cls]["score"])

                if obj_cls not in rep_scores:
                    rep_scores[obj_cls] = []
                rep_scores[obj_cls].append((i+1, t_rep_score, v_rep_score))

    # INT_LINESTYLE = "dashed"
    # REP_LINESTYLE = "solid"

    for obj_cls, color in zip(obj_classes, COLORS):
        if plot_per_interval:
            if obj_cls in int_scores:
                for (i, x, y), ls in zip(int_scores[obj_cls], LINESTYLES):
                    plt.plot(x, y, color=color, linestyle=ls)
        else:
            if obj_cls in rep_scores:
                for (i, x, y), ls in zip(rep_scores[obj_cls], LINESTYLES):
                    plt.plot(x, y, linestyle=ls, color=color)

        if obj_cls in max_scores:
            for (i, x, y), m in zip(max_scores[obj_cls], MARKERS):
                plt.scatter(x, y, marker=m, color=color, s=60, alpha=0.7)

    legend_elements = []
    for obj_cls, color in zip(obj_classes, COLORS):
        legend_elements.append(Line2D([0], [0], marker='o', color='w', label=obj_cls, markerfacecolor=color, markersize=10))
    
    for i, (ls, m) in enumerate(zip(LINESTYLES, MARKERS)):
        if i_trial is not None and i_trial != i:
            continue
        legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=ls, lw=2, label=f'Trial {i+1}'))
        legend_elements.append(Line2D([0], [0], color="w", markerfacecolor='tab:gray', marker=m, markersize=15, label=f'Output Trial {i+1}'))

    plt.title("Scores: " + scene['description'])
    plt.xlabel('Time (s)')
    plt.ylabel('Prioritization Score')
    if ylim is not None:
        plt.ylim(ylim)
    if xlim is not None:
        plt.xlim(xlim)
    plt.legend(handles=legend_elements)

    if save_fig is not None:
        plt.savefig(save_fig)
    else:
        plt.show()


def main(folder):
    with open(folder / f"all.json", "r") as f:
        scenes = json.load(f)

    
    out_folder_depth = folder / "graphs" / "depth"
    out_folder_depth.mkdir(exist_ok=True, parents=True)
    for i, scene in enumerate(scenes):
        kwargs = scene.get('kwargs', {})
        print(f"Scene {i+1}/{len(scenes)} with kwargs: {kwargs}")
        plot_scene_depth(scene, plot_all=True, save_fig=out_folder_depth / f"scene{i+1}.png", **kwargs)

    out_folder_scores = folder / "graphs" / "scores"
    out_folder_scores.mkdir(exist_ok=True, parents=True)
    for i, scene in enumerate(scenes):
        kwargs = scene.get('kwargs', {})
        kwargs = {}
        print(f"Scene {i+1}/{len(scenes)} with kwargs: {kwargs}")
        plot_scene_score(scene, i_trial=None, plot_per_interval=False, save_fig=out_folder_scores / f"scene{i+1}.png", **kwargs)
    
    # i = 7
    # scene = scenes[i]
    # kwargs = scene.get('kwargs', {})
    # print(f"Scene {i+1}/{len(scenes)} with kwargs: {kwargs}")
    # plot_scene_info(scene, **kwargs)


if __name__ == "__main__":
    folder = Path("./out")
    main(folder)
