# Resource reference

This page is generated from the local TOML catalogue. `Available` means
a verified production artifact binding or live endpoint is exposed; it
does not mean the resource is currently cached.

| ID | Category | Provider | Backend | Available | Source file |
|:---|:---|:---|:---|:---:|:---|
| `:celestrak_eop_all` | earth_orientation | celestrak | scratch | yes | `EOP-All.csv` |
| `:celestrak_space_weather_all` | space_weather | celestrak | scratch | yes | `SW-All.csv` |
| `:current_earth_high_precision` | earth_orientation | naif | scratch | yes | `earth_latest_high_prec.bpc` |
| `:current_leapseconds` | constants | naif | scratch | yes | `latest_leapseconds.tls` |
| `:de430` | ephemeris | naif | artifact | pending | `de430.bsp` |
| `:de432s` | ephemeris | naif | artifact | pending | `de432s.bsp` |
| `:de435` | ephemeris | naif | artifact | pending | `de435.bsp` |
| `:de438` | ephemeris | naif | artifact | pending | `de438.bsp` |
| `:de440` | ephemeris | naif | artifact | pending | `de440.bsp` |
| `:de440s` | ephemeris | naif | artifact | pending | `de440s.bsp` |
| `:earth_fixed` | constants | naif | artifact | pending | `earth_fixed.tf` |
| `:eros_near_msi_512q` | geometry | naif | artifact | pending | `near-a-msi-5-erosshape-v1_0_512q.bds` |
| `:eros_near_msi_64q` | geometry | naif | artifact | pending | `near-a-msi-5-erosshape-v1_0_64q.bds` |
| `:geophysical` | constants | naif | artifact | pending | `geophysical.ker` |
| `:gfz_f107` | space_weather | gfz | scratch | yes | `Kp_ap_Ap_SN_F107_since_1932.txt` |
| `:gfz_kp_ap` | space_weather | gfz | scratch | yes | `Kp_ap_Ap_SN_F107_nowcast.txt` |
| `:gm_de440` | constants | naif | artifact | pending | `gm_de440.tpc` |
| `:iers_c04` | earth_orientation | iers | scratch | yes | `eopc04.1962-now` |
| `:iers_finals2000a` | earth_orientation | iers | scratch | yes | `finals2000A.all` |
| `:itokawa_hayabusa_amica_512q` | geometry | naif | artifact | pending | `hay_a_amica_5_itokawashape_v1_0_512q.bds` |
| `:itokawa_hayabusa_amica_64q` | geometry | naif | artifact | pending | `hay_a_amica_5_itokawashape_v1_0_64q.bds` |
| `:jup347` | satellite_ephemeris | naif | artifact | pending | `jup347.bsp` |
| `:jup348` | satellite_ephemeris | naif | artifact | pending | `jup348.bsp` |
| `:jup349` | satellite_ephemeris | naif | artifact | pending | `jup349.bsp` |
| `:jup349_nameid` | satellite_ephemeris | naif | artifact | pending | `jup349_nameid.tf` |
| `:jup365` | satellite_ephemeris | naif | artifact | pending | `jup365.bsp` |
| `:mar099` | satellite_ephemeris | naif | artifact | pending | `mar099.bsp` |
| `:mar099s` | satellite_ephemeris | naif | artifact | pending | `mar099s.bsp` |
| `:moon_assoc_me` | orientation | naif | artifact | pending | `moon_assoc_me.tf` |
| `:moon_assoc_pa` | orientation | naif | artifact | pending | `moon_assoc_pa.tf` |
| `:moon_de440_250416_frames` | orientation | naif | artifact | pending | `moon_de440_250416.tf` |
| `:moon_pa_de440_200625` | orientation | naif | artifact | pending | `moon_pa_de440_200625.bpc` |
| `:naif0012` | constants | naif | artifact | pending | `naif0012.tls` |
| `:nep097` | satellite_ephemeris | naif | artifact | pending | `nep097.bsp` |
| `:nep097xl_801` | satellite_ephemeris | naif | artifact | pending | `nep097xl-801.bsp` |
| `:nep097xl_899` | satellite_ephemeris | naif | artifact | pending | `nep097xl-899.bsp` |
| `:nep098_nameid` | satellite_ephemeris | naif | artifact | pending | `nep098_nameid.tf` |
| `:nep098_part1` | satellite_ephemeris | naif | artifact | pending | `nep098_part-1.bsp` |
| `:nep098_part2` | satellite_ephemeris | naif | artifact | pending | `nep098_part-2.bsp` |
| `:nep098_part3` | satellite_ephemeris | naif | artifact | pending | `nep098_part-3.bsp` |
| `:nep101xl` | satellite_ephemeris | naif | artifact | pending | `nep101xl.bsp` |
| `:nep101xl_802` | satellite_ephemeris | naif | artifact | pending | `nep101xl-802.bsp` |
| `:nep104` | satellite_ephemeris | naif | artifact | pending | `nep104.bsp` |
| `:nep105` | satellite_ephemeris | naif | artifact | pending | `nep105.bsp` |
| `:noaa_swpc_45_day_forecast` | space_weather | noaa_swpc | scratch | yes | `45-day-forecast.json` |
| `:noaa_swpc_f107` | space_weather | noaa_swpc | scratch | yes | `f107_cm_flux.json` |
| `:noaa_swpc_planetary_k` | space_weather | noaa_swpc | scratch | yes | `planetary_k_index_1m.json` |
| `:pck00011` | constants | naif | artifact | pending | `pck00011.tpc` |
| `:phobos512` | geometry | naif | artifact | pending | `phobos512.bds` |
| `:phobos_2014_09_22` | geometry | naif | artifact | pending | `phobos_2014_09_22.bds` |
| `:phobos_3_3` | geometry | naif | artifact | pending | `phobos_3_3.bds` |
| `:plu060` | satellite_ephemeris | naif | artifact | pending | `plu060.bsp` |
| `:sat393_daphnis` | satellite_ephemeris | naif | artifact | pending | `sat393_daphnis.bsp` |
| `:sat415` | satellite_ephemeris | naif | artifact | pending | `sat415.bsp` |
| `:sat441` | satellite_ephemeris | naif | artifact | pending | `sat441.bsp` |
| `:sat441xl_part1` | satellite_ephemeris | naif | artifact | pending | `sat441xl_part-1.bsp` |
| `:sat441xl_part2` | satellite_ephemeris | naif | artifact | pending | `sat441xl_part-2.bsp` |
| `:sat455` | satellite_ephemeris | naif | artifact | pending | `sat455.bsp` |
| `:sat456` | satellite_ephemeris | naif | artifact | pending | `sat456.bsp` |
| `:sat457` | satellite_ephemeris | naif | artifact | pending | `sat457.bsp` |
| `:sat459` | satellite_ephemeris | naif | artifact | pending | `sat459.bsp` |
| `:sat459_nameid` | satellite_ephemeris | naif | artifact | pending | `sat459_nameid.tf` |
| `:sat480` | satellite_ephemeris | naif | artifact | pending | `sat480.bsp` |
| `:sat480_nameid` | satellite_ephemeris | naif | artifact | pending | `sat480_nameid.tf` |
| `:silso_daily_sunspots` | space_weather | silso | scratch | yes | `SN_d_tot_V2.0.txt` |
| `:ura111xl_701` | satellite_ephemeris | naif | artifact | pending | `ura111xl-701.bsp` |
| `:ura111xl_702` | satellite_ephemeris | naif | artifact | pending | `ura111xl-702.bsp` |
| `:ura111xl_703` | satellite_ephemeris | naif | artifact | pending | `ura111xl-703.bsp` |
| `:ura111xl_704` | satellite_ephemeris | naif | artifact | pending | `ura111xl-704.bsp` |
| `:ura111xl_705` | satellite_ephemeris | naif | artifact | pending | `ura111xl-705.bsp` |
| `:ura111xl_799` | satellite_ephemeris | naif | artifact | pending | `ura111xl-799.bsp` |
| `:ura116xl` | satellite_ephemeris | naif | artifact | pending | `ura116xl.bsp` |
| `:ura184_part1` | satellite_ephemeris | naif | artifact | pending | `ura184_part-1.bsp` |
| `:ura184_part2` | satellite_ephemeris | naif | artifact | pending | `ura184_part-2.bsp` |
| `:ura184_part3` | satellite_ephemeris | naif | artifact | pending | `ura184_part-3.bsp` |
| `:vesta_gaskell_256` | geometry | naif | artifact | pending | `vesta_gaskell_256.bds` |
| `:vesta_thomas_1997` | geometry | naif | artifact | pending | `vesta_thomas_1997.bds` |
