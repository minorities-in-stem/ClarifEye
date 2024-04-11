import json
import matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.lines import Line2D
from matplotlib.patches import Patch


def plot_scene_depth(scene, t0=None, tN=None, offset={}, max_time=None, min_time=None, ylim=None, xlim=None, save_fig=None):
    plt.figure()

    depths = {}
    gt_times = {}

    obj_classes = scene["data"].keys()

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

    COLORS = ["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple", "tab:brown"]
    LINESTYLES = ["dashed", "dotted", "dashdot"]
    GT_LINESTYLE = "solid"
    
    for obj_cls, color in zip(obj_classes, COLORS):
        for (i_trial, x, y), ls in zip(depths[obj_cls], LINESTYLES):
            plt.plot(x, y, color=color, linestyle=ls)

        plt.plot(gt_times[obj_cls], scene['data'][obj_cls], linestyle=GT_LINESTYLE)

    legend_elements = []
    for obj_cls, color in zip(obj_classes, COLORS):
        legend_elements.append(Line2D([0], [0], marker='o', color='w', label=obj_cls, markerfacecolor=color, markersize=10))
    for i, ls in enumerate(LINESTYLES):
        legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=ls, lw=2, label=f'Trial {i+1}'))
    legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=GT_LINESTYLE, lw=2, label='Ground Truth'))

    plt.title(scene['description'])
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


def plot_scene_score(scene, t0=None, tN=None, save_fig=None):
    plt.figure()

    rep_scores = {}
    int_scores = {}
    max_scores = {}

    obj_classes = set()
    for trial in scene['trials']:
        for report in trial:
            t = report["rel_timestamp"]
            obj_classes.update(report["detections"].keys())

            max_score = float('-inf')
            for obj_cls, d in report["detections"].items():
                if d["score"] > max_score:
                    max_score = d["score"]
                    max_obj_cls = obj_cls

            if max_obj_cls not in max_scores:
                max_scores[max_obj_cls] = ([], [])
            t_max_score, v_max_score = max_scores[max_obj_cls]
            t_max_score.append(t)
            v_max_score.append(max_score)
    
    for obj_cls in obj_classes:
        for i, trial in enumerate(scene['trials']):
            t_rep_score = []
            v_rep_score = []

            t_int_score = []
            v_int_score = []

            for j, report in enumerate(trial):
                if obj_cls in report["detections"]:
                    t = report["rel_timestamp"]
                    t_rep_score.append(t)
                    v_rep_score.append(report["detections"][obj_cls]["score"])

                for k, per_interval in enumerate(report["per_interval"]):
                    if obj_cls in per_interval["detections"]:
                        t = per_interval["rel_timestamp"]
                        t_int_score.append(t)
                        v_int_score.append(per_interval["detections"][obj_cls]["score"])

            if obj_cls not in int_scores:
                int_scores[obj_cls] = []

            int_scores[obj_cls].append((i+1, t_int_score, v_int_score))
            rep_scores[obj_cls] = (t_rep_score, v_rep_score)

    COLORS = ["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple", "tab:brown"]
    INT_LINESTYLE = "dashed"
    REP_LINESTYLE = "solid"
    
    for obj_cls, color in zip(obj_classes, COLORS):
        if obj_cls in int_scores:
            for i_trial, x, y in int_scores[obj_cls]:
                plt.plot(x, y, color=color, linestyle=INT_LINESTYLE)

        if obj_cls in rep_scores:
            x, y = rep_scores[obj_cls]
            plt.plot(x, y, linestyle=REP_LINESTYLE)

        if obj_cls in max_scores:
            x, y = max_scores[obj_cls]
            plt.scatter(x, y, marker=(5, 1), color=color, s=30)

    legend_elements = []
    for obj_cls, color in zip(obj_classes, COLORS):
        legend_elements.append(Line2D([0], [0], marker='o', color='w', label=obj_cls, markerfacecolor=color, markersize=10))
    legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=INT_LINESTYLE, lw=2, label='Per Interval'))
    legend_elements.append(Line2D([0], [0], color='tab:gray', linestyle=REP_LINESTYLE, lw=2, label='Report'))

    plt.title(scene['description'])
    plt.xlabel('Time (s)')
    plt.ylabel('Score')
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
        plot_scene_depth(scene, save_fig=out_folder_depth / f"scene{i+1}.png", **kwargs)

    out_folder_scores = folder / "graphs" / "scores"
    out_folder_scores.mkdir(exist_ok=True, parents=True)
    for i, scene in enumerate(scenes):
        print(f"Scene {i+1}/{len(scenes)}")
        plot_scene_score(scene, save_fig=out_folder_scores / f"scene{i+1}.png")
    
    # i = 7
    # scene = scenes[i]
    # kwargs = scene.get('kwargs', {})
    # print(f"Scene {i+1}/{len(scenes)} with kwargs: {kwargs}")
    # plot_scene_info(scene, **kwargs)


if __name__ == "__main__":
    folder = Path("./out")
    main(folder)
