# 技术依据与适用条件

制作日期：2026-10-26。视频为自绘动画与系统中文语音，无第三方影视素材。

1. [Analog Devices — Impedance Matching](https://www.analog.com/en/resources/glossary/impedance-matching.html)
   复阻抗与共轭匹配；本片明确限定固定线性戴维南源与指定频率。
2. [Keysight — Reflection Measurements](https://helpfiles.keysight.com/csg/pxivna/Tutorials/Reflection_Measurements.htm)
   反射系数是反射电压与入射电压之比。无反射条件是负载等于线路特性阻抗。
3. [Analog Devices — Understanding Wave Reflections](https://www.analog.com/en/resources/analog-dialogue/raqs/2021/12/16/16/41/raq-issue-197.html)
   行波、特性阻抗与不连续处反射。
4. [Texas Instruments — High Speed Analog Design and Application Seminar](https://www.ti.com/lit/ml/slyp172/slyp172.pdf)
   边沿时间、传播延时与线路电长度。
5. [Texas Instruments — Guidelines for Measuring Audio Power Amplifier Performance](https://www.ti.com/lit/an/sloa068/sloa068.pdf)
   音频源低输出阻抗与高输入阻抗的电压测量原则。

## 算例

- 无损线路且 Z₀=50 Ω 为实数，负载为纯电阻。Γ=(ZL−Z₀)/(ZL+Z₀)。
- ZL=100 Ω：Γ=+1/3；反射功率占入射功率 1/9；负载吸收 8/9。不是整机供电效率。
- ZL=25 Ω：Γ=−1/3，反射电压极性翻转；功率仍为正且占入射功率 1/9。
- 直流 10 V 戴维南源，Rs=50 Ω：PL=Vs²RL/(Rs+RL)²；RL=50 Ω 时 PL=0.5 W；内阻耗散0.5 W。
- 复数源 Zs=50+j20 Ω，最大平均功率的负载 ZL=50−j20 Ω。
- 理想变压器 N1:N2=1:2，Zin=(N1/N2)²×200 Ω=50 Ω；实际变压器有损耗且有工作频带。
- 音频纯电阻近似分压：10000/(100+10000)=99.0099%。
- 传播速度假设为2×10⁸ m/s；1 m 线单程延时5 ns。该速度为示例，不代表所有介质。
