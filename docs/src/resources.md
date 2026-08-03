# Resource reference

This page is generated from the local TOML catalogue. `Available` means
a locked artifact binding or live endpoint is exposed; it
does not mean the resource is currently cached.

| ID | Category | Provider | Backend | Available | Source file |
|:---|:---|:---|:---|:---:|:---|
| `:celestrak_eop_all` | earth_orientation | celestrak | scratch | yes | `EOP-All.csv` |
| `:celestrak_space_weather_all` | space_weather | celestrak | scratch | yes | `SW-All.csv` |
| `:current_earth_high_precision` | earth_orientation | naif | scratch | yes | `earth_latest_high_prec.bpc` |
| `:current_leapseconds` | constants | naif | scratch | yes | `latest_leapseconds.tls` |
| `:de430` | ephemeris | naif | artifact | yes | `de430.bsp` |
| `:de431_part1` | ephemeris | naif | artifact | pending | `de431_part-1.bsp` |
| `:de431_part2` | ephemeris | naif | artifact | pending | `de431_part-2.bsp` |
| `:de432s` | ephemeris | naif | artifact | yes | `de432s.bsp` |
| `:de435` | ephemeris | naif | artifact | yes | `de435.bsp` |
| `:de438` | ephemeris | naif | artifact | yes | `de438.bsp` |
| `:de440` | ephemeris | naif | artifact | yes | `de440.bsp` |
| `:de440s` | ephemeris | naif | artifact | yes | `de440s.bsp` |
| `:de441_part1` | ephemeris | naif | artifact | pending | `de441_part-1.bsp` |
| `:de441_part2` | ephemeris | naif | artifact | pending | `de441_part-2.bsp` |
| `:de442` | ephemeris | naif | artifact | yes | `de442.bsp` |
| `:de442s` | ephemeris | naif | artifact | yes | `de442s.bsp` |
| `:earth_fixed` | constants | naif | artifact | yes | `earth_fixed.tf` |
| `:eros_near_msi_512q` | geometry | naif | artifact | yes | `near-a-msi-5-erosshape-v1_0_512q.bds` |
| `:eros_near_msi_64q` | geometry | naif | artifact | yes | `near-a-msi-5-erosshape-v1_0_64q.bds` |
| `:geophysical` | constants | naif | artifact | yes | `geophysical.ker` |
| `:gfz_f107` | space_weather | gfz | scratch | yes | `Kp_ap_Ap_SN_F107_since_1932.txt` |
| `:gfz_kp_ap` | space_weather | gfz | scratch | yes | `Kp_ap_Ap_SN_F107_nowcast.txt` |
| `:ggm05c` | gravity | icgem | artifact | yes | `GGM05C.gfc` |
| `:gm_de440` | constants | naif | artifact | yes | `gm_de440.tpc` |
| `:goco06s` | gravity | gfz | artifact | yes | `GOCO06s.gfc` |
| `:iers_c04` | earth_orientation | iers | scratch | yes | `eopc04.1962-now` |
| `:iers_finals2000a` | earth_orientation | iers | scratch | yes | `finals2000A.all` |
| `:itokawa_hayabusa_amica_512q` | geometry | naif | artifact | yes | `hay_a_amica_5_itokawashape_v1_0_512q.bds` |
| `:itokawa_hayabusa_amica_64q` | geometry | naif | artifact | yes | `hay_a_amica_5_itokawashape_v1_0_64q.bds` |
| `:jup348` | satellite_ephemeris | naif | artifact | yes | `jup348.bsp` |
| `:jup349` | satellite_ephemeris | naif | artifact | yes | `jup349.bsp` |
| `:jup349_nameid` | satellite_ephemeris | naif | artifact | yes | `jup349_nameid.tf` |
| `:mar099s` | satellite_ephemeris | naif | artifact | yes | `mar099s.bsp` |
| `:moon_assoc_me` | orientation | naif | artifact | yes | `moon_assoc_me.tf` |
| `:moon_assoc_pa` | orientation | naif | artifact | yes | `moon_assoc_pa.tf` |
| `:moon_de440_250416_frames` | orientation | naif | artifact | yes | `moon_de440_250416.tf` |
| `:moon_pa_de440_200625` | orientation | naif | artifact | yes | `moon_pa_de440_200625.bpc` |
| `:naif0012` | constants | naif | artifact | yes | `naif0012.tls` |
| `:nep097` | satellite_ephemeris | naif | artifact | yes | `nep097.bsp` |
| `:nep098_nameid` | satellite_ephemeris | naif | artifact | yes | `nep098_nameid.tf` |
| `:nep105` | satellite_ephemeris | naif | artifact | yes | `nep105.bsp` |
| `:noaa_swpc_45_day_forecast` | space_weather | noaa_swpc | scratch | yes | `45-day-forecast.json` |
| `:noaa_swpc_f107` | space_weather | noaa_swpc | scratch | yes | `f107_cm_flux.json` |
| `:noaa_swpc_planetary_k` | space_weather | noaa_swpc | scratch | yes | `planetary_k_index_1m.json` |
| `:pck00011` | constants | naif | artifact | yes | `pck00011.tpc` |
| `:phobos512` | geometry | naif | artifact | yes | `phobos512.bds` |
| `:phobos_2014_09_22` | geometry | naif | artifact | yes | `phobos_2014_09_22.bds` |
| `:phobos_3_3` | geometry | naif | artifact | yes | `phobos_3_3.bds` |
| `:plu060` | satellite_ephemeris | naif | artifact | yes | `plu060.bsp` |
| `:sat393_daphnis` | satellite_ephemeris | naif | artifact | yes | `sat393_daphnis.bsp` |
| `:sat456` | satellite_ephemeris | naif | artifact | yes | `sat456.bsp` |
| `:sat457` | satellite_ephemeris | naif | artifact | yes | `sat457.bsp` |
| `:sat459` | satellite_ephemeris | naif | artifact | yes | `sat459.bsp` |
| `:sat459_nameid` | satellite_ephemeris | naif | artifact | yes | `sat459_nameid.tf` |
| `:sat480` | satellite_ephemeris | naif | artifact | yes | `sat480.bsp` |
| `:sat480_nameid` | satellite_ephemeris | naif | artifact | yes | `sat480_nameid.tf` |
| `:silso_daily_sunspots` | space_weather | silso | scratch | yes | `SN_d_tot_V2.0.txt` |
| `:ura184_part1` | satellite_ephemeris | naif | artifact | yes | `ura184_part-1.bsp` |
| `:ura184_part2` | satellite_ephemeris | naif | artifact | yes | `ura184_part-2.bsp` |
| `:ura184_part3` | satellite_ephemeris | naif | artifact | yes | `ura184_part-3.bsp` |
| `:vesta_gaskell_256` | geometry | naif | artifact | yes | `vesta_gaskell_256.bds` |
| `:vesta_thomas_1997` | geometry | naif | artifact | yes | `vesta_thomas_1997.bds` |
