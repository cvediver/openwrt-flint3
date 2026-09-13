# PR staging for perceival/openwrt-flint3

| From (this fork) | To (upstream) | PR | Description |
|---|---|---|---|
| pr/device-correctness | perceival/openwrt-flint3 flint3-be9300 | GL-BE9300 device correctness | Factory-current board data (containers held generic 2.4G bdwlan.bin and pre-release b1019), wifi-MAC uci-default retention on fresh installs, post-SSR phy-add recovery net, 2.4G caldata extent documentation, U7 Pro XGS dead board-id property fix |
| pr/flash-safety | perceival/openwrt-flint3 flint3-be9300 | Flash and restore safety | Stock-restore verifies and size-checks every FIT section before the first destructive write; KERNEL_SIZE guard against the 7168k 0:HLOS partition |
| pr/rtl837x-hardening | perceival/openwrt-flint3 flint3-be9300 | rtl837x robustness | Bounded probe retry for transient MDIO errors, mutexes for the shared indirect-access engines (MIB/ITA/SMI/SerDes), reject bridge VLANs in the dsa_8021q reserved range |
| pr/ppe-datapath | perceival/openwrt-flint3 flint3-be9300 | PPE datapath fixes | PPE frequency table with the 300 MHz CMN-PLL entry (tk154's amendment; stock runs 300 MHz), Tx queues stopped during carrier loss stayed stopped after link-up - wake them, software csum/GSO fallback for multi-tagged frames |
| pr/ath12k-robustness | perceival/openwrt-flint3 flint3-be9300 | ath12k crash robustness and first-assoc self-heal | IPQ5332 NoC SError series (coredump off for this target, recovery link reset, link-dead BAR gating, forced MHI teardown), WSI group recovery completion for partial crashes, first-association dead-TX-burst self-heal with firmware-RE rationale, ML peer ID bookkeeping hardening |
