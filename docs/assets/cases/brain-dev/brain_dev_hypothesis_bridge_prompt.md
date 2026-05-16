# 从统计结果到研究假设

## Prompt

一张中文横版科学解释图，用于演示 `ggai` 如何帮助研究者从真实统计结果中更快看出 pattern，并形成下一步假设。必须是单张 16:9 宽幅图，阅读顺序从左到右，明确分成三栏：左栏 `真实证据`，中栏 `主模式`，右栏 `下一步假设`。左栏展示真实脑发育案例 GSE207092 的统计证据窗：clusterProfiler dotplot、小型 term-overlap map、简短方法标注 `NSC vs Neuron | limma + empirical Bayes | n=2 per group`，视觉上让人一眼看出这是 grounded evidence，但同时带有“信息密、读图慢”的压力感。中栏必须把复杂结果压缩成一个非常清晰的发育转变：左侧是 NSC 区，短标签只有 `cell cycle`、`DNA replication`、`patterning`，画面像复制车间、分裂程序、蓝图和时钟；右侧是 Neuron 区，短标签只有 `synapse assembly`、`postsynapse organization`、`vesicle cycling`、`neurotransmitter transport`，画面像神经连接、突触插槽、囊泡循环和发光通信网络；中间用一条明显的桥、箭头或过渡带，把主模式收束成一句 `从增殖 / patterning 到连接 / communication`。右栏放三张紧凑的 hypothesis cards，而不是长段落：`Hypothesis 1: cell-cycle exit may be coupled to synaptic maturation`，`Hypothesis 2: bridge genes between progenitor programs and neuronal communication are priority targets`，`Hypothesis 3: follow-up validation should focus on the transition zone, not only term ranking`；右栏必须看起来像研究讨论板，而不是结论海报。整张图的关键是强调链路：`raw chart -> compressed pattern -> testable hypotheses`，并明确传达这不是因果证明，而是 hypothesis acceleration。中文标题大而清楚：`从统计结果到研究假设`；可加一行很短的副标题：`ggai 帮助研究者更快看出 pattern`。文字必须极少，全部为短标签，适合汇报投影阅读。整体风格要像成熟的 scientific explainer board：克制、专业、清晰、可扫描，不要卡通，不要 BioRender 风器官拼贴，不要咨询公司流程图，不要赛博海报。 Style: grey-white laboratory background, restrained teal and slate as main colors, one sharp accent color for hypothesis cards, crisp evidence windows, thin annotation lines, mature editorial scientific layout. Composition: 16:9 horizontal, three-column evidence-to-pattern-to-hypothesis structure, strong central transition, dense but clean, readable at presentation distance. Avoid: watermark, dense paragraph text, tiny illegible labels, cartoon mascot, cute character, purple cyberpunk, management consulting infographic style, decorative 3D icons, generic stock-science wallpaper

## References

- brain_dev_clusterprofiler_dotplot.png
- brain_dev_clusterprofiler_emapplot.png
- brain_dev_plot_reader_best.png
- brain_dev_infographic_best.png
