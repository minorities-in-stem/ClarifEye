import math
import json

from pathlib import Path

def IN2M(inches):
    return inches * 0.0254

SCENES = [
    {
        "description": "Person walking towards user",
        "trials": ["16_38_59", "16_40_30", "16_41_24"],
        "data": {
            "start": IN2M(100),
            "end": IN2M(20),
            "speed": 8,
        }
    },
    {
        "description": "Person walking horizontally across frame",
        "trials": ["16_53_04", "16_54_08", "16_55_36"],
        "data": {
            "end": IN2M(math.sqrt(100**2 + 20**2)),
            "start": IN2M(math.sqrt(100**2 + 20**2)),
            "speed": 8,
        }
    },
    {
        "description": "Person walking away from user",
        "trials": ["16_57_37", "16_59_00", "17_00_05"],
        "data": {
            "start dist": IN2M(20),
            "end dist": IN2M(100),
            "speed": 8
        }
    },
    {
        "description": "User stands still",
        "trials": ["17_11_44"],
        "data": {
            "person": IN2M(97),
            "fire_hydrant": IN2M(85),
            "tree": IN2M(97+280)
        }
    },
    {
        "description": "Person in frame in front of fire_hydrant, then moves out of frame",
        "trials": ["17_17_02", "17_18_07", "17_18_51"],
        "data": {
            "fire_hydrant": IN2M(120),
            "person": IN2M(108)
        }
    },
    {
        "description": "User walks towards fire_hydrant",
        "trials": ["17_23_16", "17_24_22", "17_25_16"],
        "data": {
            "start": IN2M(216),
            "end": IN2M(64),
        }
    },
    {
        "description": "User walking, stationary pole, person walks towards pole, user and peson meet at pole",
        "trials": ["17_32_21", "17_33_19", "17_34_04"],
        "data": {
        }
    },
    {
        "description": "User walks towards 3 bollards and 1 fire_hydrant, people in background",
        "trials": ["17_46_07", "17_46_47", "17_47_39"],
        "data": {}
    }
]


def main(folder):
    for scene in SCENES:
        trials = []
        for t in scene["trials"]:
            with open(folder / f"result-{t}.json") as f:
                trials.append(json.load(f))
        scene["trials"] = trials

    with open(folder / f"all.json", "w") as f:
        json.dump(SCENES, f, indent=2)


            


if __name__ == "__main__":
    folder = Path("./verification-data")
    main(folder)
