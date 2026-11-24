# Dados dos carros. Para adicionar um carro novo, copie uma entrada e veja o LEIA-ME.txt
class_name CarsData
extends RefCounted

const ALL := {
    "p911ts": {
        "name": "Porsche 911 Turbo S", "desc": "Cupê alemão com tração integral e arranque brutal.", "model": "res://cars/p911ts.glb",
        "paint": Color(0.070, 0.160, 0.420), "power": "650 cv", "zero100": "2,7 s", "real_top": "330 km/h",
        "mass": 1640.0, "engine": 14432.0, "brake": 43.7, "max_kmh": 100.0, "grip_front": 3.50, "grip_rear": 3.70, "steer": 0.50,
        "wheel_radius": 0.350, "wheel_y": 0.530, "com": Vector3(0.000, 0.364, 0.000),
        "wheels": {"FL": Vector3(-0.806, 0.530, -1.225), "FR": Vector3(0.806, 0.530, -1.225), "RL": Vector3(-0.771, 0.530, 1.225), "RR": Vector3(0.771, 0.530, 1.225)},
        "collision": [{"pos": Vector3(0.000, 0.493, 0.000), "size": Vector3(1.786, 0.546, 4.249)}, {"pos": Vector3(0.000, 1.040, 0.050), "size": Vector3(1.178, 0.364, 1.718)}],
        "headlights": [Vector3(-0.600, 0.760, -1.815), Vector3(0.600, 0.760, -1.815)],
        "length": 4.520, "width": 1.900, "height": 1.300
    },
    "revuelto": {
        "name": "Lamborghini Revuelto", "desc": "Híbrido V12 de linhas afiadas, baixo e largo.", "model": "res://cars/revuelto.glb",
        "paint": Color(0.950, 0.780, 0.030), "power": "1015 cv", "zero100": "2,5 s", "real_top": "350 km/h",
        "mass": 1900.0, "engine": 16150.0, "brake": 50.7, "max_kmh": 100.0, "grip_front": 3.50, "grip_rear": 3.80, "steer": 0.48,
        "wheel_radius": 0.360, "wheel_y": 0.540, "com": Vector3(0.000, 0.326, 0.000),
        "wheels": {"FL": Vector3(-0.866, 0.540, -1.389), "FR": Vector3(0.866, 0.540, -1.389), "RL": Vector3(-0.826, 0.540, 1.389), "RR": Vector3(0.826, 0.540, 1.389)},
        "collision": [{"pos": Vector3(0.000, 0.465, 0.000), "size": Vector3(1.911, 0.490, 4.650)}, {"pos": Vector3(0.000, 0.933, 0.160), "size": Vector3(1.260, 0.326, 1.880)}],
        "headlights": [Vector3(-0.620, 0.500, -2.329), Vector3(0.620, 0.500, -2.329)],
        "length": 4.947, "width": 2.033, "height": 1.166
    },
    "mclaren750s": {
        "name": "McLaren 750S", "desc": "Supercarro leve e afiado, de cabine adiantada.", "model": "res://cars/mclaren750s.glb",
        "paint": Color(1.000, 0.450, 0.040), "power": "750 cv", "zero100": "2,8 s", "real_top": "332 km/h",
        "mass": 1330.0, "engine": 11704.0, "brake": 35.5, "max_kmh": 100.0, "grip_front": 3.70, "grip_rear": 3.90, "steer": 0.50,
        "wheel_radius": 0.350, "wheel_y": 0.530, "com": Vector3(0.000, 0.335, 0.000),
        "wheels": {"FL": Vector3(-0.821, 0.530, -1.335), "FR": Vector3(0.821, 0.530, -1.335), "RL": Vector3(-0.781, 0.530, 1.335), "RR": Vector3(0.781, 0.530, 1.335)},
        "collision": [{"pos": Vector3(0.000, 0.471, 0.000), "size": Vector3(1.814, 0.502, 4.295)}, {"pos": Vector3(0.000, 0.957, 0.065), "size": Vector3(1.197, 0.335, 1.736)}],
        "headlights": [Vector3(-0.600, 0.550, -2.235), Vector3(0.600, 0.550, -2.235)],
        "length": 4.569, "width": 1.930, "height": 1.196
    },
    "gt3rs": {
        "name": "Porsche 911 GT3 RS", "desc": "Aerodinâmica de pista com asa gigante. Boxer 4.0 aspirado.", "model": "res://cars/gt3rs.glb",
        "paint": Color(0.850, 0.050, 0.040), "power": "525 cv", "zero100": "3,2 s", "real_top": "296 km/h",
        "mass": 1450.0, "engine": 11020.0, "brake": 38.7, "max_kmh": 100.0, "grip_front": 3.90, "grip_rear": 4.10, "steer": 0.50,
        "wheel_radius": 0.388, "wheel_radius_rear": 0.388, "wheel_y": 0.568, "com": Vector3(0.000, 0.360, 0.040),
        "wheels": {"FL": Vector3(-0.770, 0.568, -1.228), "FR": Vector3(0.770, 0.568, -1.228), "RL": Vector3(-0.770, 0.568, 1.228), "RR": Vector3(0.770, 0.568, 1.228)},
        "collision": [{"pos": Vector3(0.000, 0.500, 0.014), "size": Vector3(1.852, 0.600, 4.252)}, {"pos": Vector3(0.000, 1.043, 0.288), "size": Vector3(1.168, 0.487, 1.646)}],
        "headlights": [Vector3(-0.604, 0.621, -2.192), Vector3(0.604, 0.621, -2.192)],
        "own_interior": true, "eye": Vector3(-0.360, 1.021, 0.408), "exhaust": [Vector3(-0.220, 0.360, 2.250), Vector3(0.220, 0.360, 2.250)],
        "length": 4.572, "width": 2.013, "height": 1.380
    },
    "sf90": {
        "name": "Ferrari SF90 XX Stradale", "desc": "Híbrido V8 com mais de 1000 cv, versão pista da SF90.", "model": "res://cars/sf90.glb",
        "paint": Color(0.850, 0.040, 0.030), "power": "1030 cv", "zero100": "2,3 s", "real_top": "320 km/h",
        "mass": 1570.0, "engine": 14444.0, "brake": 41.9, "max_kmh": 100.0, "grip_front": 3.70, "grip_rear": 3.90, "steer": 0.50,
        "wheel_radius": 0.335, "wheel_radius_rear": 0.342, "wheel_y": 0.515, "com": Vector3(0.000, 0.360, 0.140),
        "wheels": {"FL": Vector3(-0.821, 0.515, -1.288), "FR": Vector3(0.821, 0.515, -1.288), "RL": Vector3(-0.794, 0.522, 1.288), "RR": Vector3(0.794, 0.522, 1.288)},
        "collision": [{"pos": Vector3(0.000, 0.417, -0.149), "size": Vector3(1.993, 0.434, 4.380)}, {"pos": Vector3(0.000, 0.827, -0.149), "size": Vector3(1.257, 0.386, 1.696)}],
        "headlights": [Vector3(-0.650, 0.492, -2.424), Vector3(0.650, 0.492, -2.424)],
        "own_interior": true, "eye": Vector3(-0.360, 0.809, -0.029), "exhaust": [Vector3(-0.220, 0.360, 2.156), Vector3(0.220, 0.360, 2.156)],
        "length": 4.710, "width": 2.167, "height": 1.094
    },
    "valkyrie": {
        "name": "Aston Martin Valkyrie", "desc": "Hipercarro de pista com asas enormes e cabine estreita.", "model": "res://cars/valkyrie.glb",
        "paint": Color(0.140, 0.240, 0.200), "power": "1160 cv", "zero100": "2,5 s", "real_top": "350 km/h",
        "mass": 1270.0, "engine": 12700.0, "brake": 33.9, "max_kmh": 100.0, "grip_front": 4.20, "grip_rear": 4.40, "steer": 0.46,
        "wheel_radius": 0.351, "wheel_radius_rear": 0.369, "wheel_y": 0.531, "com": Vector3(0.000, 0.360, 0.140),
        "wheels": {"FL": Vector3(-0.829, 0.531, -1.384), "FR": Vector3(0.829, 0.531, -1.384), "RL": Vector3(-0.794, 0.549, 1.384), "RR": Vector3(0.794, 0.549, 1.384)},
        "collision": [{"pos": Vector3(0.000, 0.397, -0.064), "size": Vector3(1.699, 0.394, 4.184)}, {"pos": Vector3(0.000, 0.775, -0.244), "size": Vector3(1.071, 0.361, 1.620)}],
        "headlights": [Vector3(-0.554, 0.461, -2.233), Vector3(0.554, 0.461, -2.233)],
        "own_interior": true, "eye": Vector3(-0.360, 0.758, -0.124), "exhaust": [Vector3(-0.220, 0.360, 2.136), Vector3(0.220, 0.360, 2.136)],
        "length": 4.499, "width": 1.847, "height": 1.025
    },
    "veneno": {
        "name": "Lamborghini Veneno", "desc": "V12 de 750 cv, aerodinâmica extrema e visual de caça.", "model": "res://cars/veneno.glb",
        "paint": Color(0.980, 0.110, 0.000), "power": "750 cv", "zero100": "2,9 s", "real_top": "355 km/h",
        "mass": 1450.0, "engine": 11800.0, "brake": 40.5, "max_kmh": 100.0, "grip_front": 4.00, "grip_rear": 4.20, "steer": 0.48,
        "wheel_radius": 0.334, "wheel_radius_rear": 0.373, "wheel_y": 0.514, "com": Vector3(0.000, 0.360, 0.140),
        "wheels": {"FL": Vector3(-0.795, 0.514, -1.268), "FR": Vector3(0.795, 0.514, -1.268), "RL": Vector3(-0.786, 0.553, 1.268), "RR": Vector3(0.786, 0.553, 1.268)},
        "collision": [{"pos": Vector3(0.000, 0.420, -0.090), "size": Vector3(1.833, 0.441, 4.416)}, {"pos": Vector3(0.000, 0.835, -0.232), "size": Vector3(1.155, 0.390, 1.709)}],
        "headlights": [Vector3(-0.598, 0.497, -2.384), Vector3(0.598, 0.497, -2.384)],
        "own_interior": true, "eye": Vector3(-0.360, 0.817, -0.112), "exhaust": [Vector3(-0.220, 0.360, 2.234), Vector3(0.220, 0.360, 2.234)],
        "length": 4.748, "width": 1.992, "height": 1.104
    },
    "onceleven": {
        "name": "Mercedes-Benz Vision One-Eleven", "desc": "Conceito elétrico com portas em asa e muito torque instantâneo.", "model": "res://cars/onceleven.glb",
        "paint": Color(0.920, 0.920, 0.940), "power": "conceito elétrico", "zero100": "2,5 s", "real_top": "260 km/h",
        "mass": 1650.0, "engine": 9800.0, "brake": 40.0, "max_kmh": 100.0, "grip_front": 3.70, "grip_rear": 3.90, "steer": 0.52,
        "wheel_radius": 0.392, "wheel_radius_rear": 0.392, "wheel_y": 0.572, "com": Vector3(0.000, 0.360, 0.040),
        "wheels": {"FL": Vector3(-0.890, 0.572, -1.450), "FR": Vector3(0.888, 0.572, -1.450), "RL": Vector3(-0.888, 0.572, 1.450), "RR": Vector3(0.890, 0.572, 1.450)},
        "collision": [{"pos": Vector3(0.000, 0.446, -0.153), "size": Vector3(1.902, 0.491, 4.304)}, {"pos": Vector3(0.000, 0.901, -0.061), "size": Vector3(1.199, 0.420, 1.666)}],
        "headlights": [Vector3(-0.620, 0.536, -2.387), Vector3(0.620, 0.536, -2.387)],
        "own_interior": true, "eye": Vector3(-0.360, 0.882, 0.059), "exhaust": [Vector3(-0.220, 0.360, 2.110), Vector3(0.220, 0.360, 2.110)],
        "length": 4.628, "width": 2.067, "height": 1.192
    },
    "polestar2": {
        "name": "Polestar 2", "desc": "Sedã elétrico fácil de dirigir. Bom para começar.", "model": "res://cars/polestar2.glb",
        "paint": Color(0.920, 0.920, 0.940), "power": "300 kW", "zero100": "4,7 s", "real_top": "205 km/h",
        "mass": 1500.0, "engine": 9000.0, "brake": 40.0, "max_kmh": 100.0, "grip_front": 3.40, "grip_rear": 3.60, "steer": 0.55,
        "wheel_radius": 0.370, "wheel_y": 0.550, "com": Vector3(0.000, 0.350, 0.000),
        "wheels": {"FL": Vector3(-0.800, 0.550, -1.370), "FR": Vector3(0.800, 0.550, -1.370), "RL": Vector3(-0.800, 0.550, 1.350), "RR": Vector3(0.800, 0.550, 1.350)},
        "collision": [{"pos": Vector3(0.000, 0.780, 0.000), "size": Vector3(1.800, 0.600, 4.300)}, {"pos": Vector3(0.000, 1.200, 0.300), "size": Vector3(1.500, 0.500, 2.200)}],
        "headlights": [Vector3(-0.400, 0.580, -2.300), Vector3(0.400, 0.580, -2.300)],
        "length": 4.600, "width": 1.860, "height": 1.480
    },
}
