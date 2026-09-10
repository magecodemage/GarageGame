from car_common import make_material


def build_materials():
    return {
        "car_paint": make_material("car_paint", (0.16, 0.28, 0.32), metallic=0.65, roughness=0.22),
        "black_plastic": make_material("black_plastic", (0.018, 0.022, 0.026), roughness=0.62),
        "dark_plastic": make_material("dark_plastic", (0.045, 0.052, 0.06), roughness=0.5),
        "rubber": make_material("rubber", (0.012, 0.014, 0.016), roughness=0.78),
        "steel": make_material("steel", (0.28, 0.31, 0.33), metallic=0.82, roughness=0.3),
        "aluminum": make_material("aluminum", (0.58, 0.62, 0.65), metallic=0.75, roughness=0.24),
        "glass": make_material("glass", (0.055, 0.12, 0.16), metallic=0.05, roughness=0.1, alpha=0.42),
        "fabric": make_material("fabric", (0.105, 0.11, 0.12), roughness=0.92),
        "interior_plastic": make_material("interior_plastic", (0.035, 0.04, 0.047), roughness=0.72),
        "brake_material": make_material("brake_material", (0.34, 0.24, 0.16), metallic=0.6, roughness=0.48),
        "red_lens": make_material("red_lens", (0.55, 0.012, 0.018), metallic=0.05, roughness=0.2, alpha=0.82),
        "clear_lens": make_material("clear_lens", (0.72, 0.82, 0.9), metallic=0.05, roughness=0.12, alpha=0.72),
        "amber": make_material("amber", (0.95, 0.28, 0.025), roughness=0.25),
        "engine_black": make_material("engine_black", (0.025, 0.03, 0.032), metallic=0.15, roughness=0.65),
        "battery": make_material("battery_case", (0.055, 0.065, 0.07), roughness=0.7),
        "coolant": make_material("coolant_plastic", (0.72, 0.75, 0.66), roughness=0.45, alpha=0.75),
    }
