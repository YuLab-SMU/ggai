# 脑发育从增殖到连接

## Prompt

一张中文高密度科学信息图，用 baoyu-infographic 的 dense-modules 布局和 pop-laboratory 视觉语言， 总结真实小鼠脑发育数据集 GSE207092 中 NSC vs Neuron 的差异表达、GO 富集和生物学解释。 模块 A-01 数据：GSE207092，小鼠脑发育 RNA-seq，比较 NSC vs Neuron，各 2 个重复样本，用清楚的样本卡片和流程线展示真实数据来源, 模块 A-02 统计：limma 线性模型加 empirical Bayes moderation，强调 n=2 每组时的方差稳定；用设计矩阵和收缩示意，而不是公式墙, 模块 B-01 计数：padj<0.05 共 11052 个基因，|logFC|>1 共 6181 个，NSC-up 3179 个，Neuron-up 3002 个, 模块 B-02 NSC 程序：mitotic cell cycle phase transition (167 genes, padj 1.2e-50); regulation of cell cycle phase transition (170 genes, padj 3.2e-50); chromosome segregation (162 genes, padj 1.8e-49); negative regulation of cell cycle (155 genes, padj 3.7e-49)，视觉上表现为复制、纺锤体、染色体分离和细胞周期推进, 模块 B-03 Neuron 程序：regulation of synapse structure or activity (183 genes, padj 1.8e-77); regulation of synapse organization (177 genes, padj 5.8e-74); synapse assembly (154 genes, padj 5.6e-73); vesicle-mediated transport in synapse (155 genes, padj 9.0e-71); synaptic vesicle cycle (129 genes, padj 1.8e-59)，视觉上表现为树突延伸、突触装配、囊泡循环和信号传递, 模块 C-01 证据窗：把 dotplot、term map 和 gene-term network 作为小型证据视窗嵌入版面，让人看得出这是从真实统计图提炼而来, 模块 C-02 结论：把整张图收束成一句主线，脑发育并不是随机变形，而是从增殖中的神经干细胞，转向会建立连接和传递信息的成熟神经元 必须明显区分 数据 / 统计方法 / 统计结果 / 生物学解释 四层，不要混成一张装饰海报, 所有模块用坐标标签，如 A-01、B-02、C-01，形成实验手册感, 中文标题与短标签必须大而清晰，可读；正文只允许短句，不允许密密麻麻的段落, 参考图只能作为证据窗和几何线索，不能整张照搬原图, 保留真实数字和关键 GO term 名称，英文术语可直接出现, 整体视觉要像高级科研传播信息图，不是卡通，不是赛博海报，不是简历模板 Style: pop-laboratory: 灰白底带微弱 blueprint grid，主色为 muted teal， 警示和重点用 fluorescent pink，关键词用 lemon yellow marker highlight， 大量细线坐标、标尺、十字准星、技术参数小标注，形成实验室手册和流行图形设计的张力。 Composition: 竖版 3:4，高密度 7 模块排布，上方主标题，中部方法和结果模块， 下方证据窗和结论模块，留白很少但层次非常清楚。 Avoid: watermark, tiny illegible text, dense paragraph text, cartoon mascot, generic biotech poster, purple cyberpunk, soft pastel scrapbook, medical clipart, anime pin-up, empty decorative whitespace

## References

- brain_dev_clusterprofiler_dotplot.png
- brain_dev_clusterprofiler_emapplot.png
