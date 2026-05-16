# 脑发育高级解释信息图

这张图把脑发育案例拆成四层：数据、统计方法、统计结果、生物学解释。

## 关键事实

- 数据集：GSE207092
- 比较：NSC vs Neuron
- 统计方法：limma + empirical Bayes moderation
- 显著基因：11052
- 强效差异基因：6181
- NSC-up：3179
- Neuron-up：3002

## 这张图想传达什么

它不是在重画一个 dotplot，而是在把真实统计证据重新组织成一张一眼能读懂的解释图。
上半部讲数据和 limma/eBayes 为什么合理，下半部讲富集结果如何落到神经发育这个生物学故事上。

## 视觉策略

- 布局：baoyu-infographic 的 dense-modules
- 风格：pop-laboratory
- grounding：默认使用关键统计参考图，必要时可用 GGAI_DEMO_MAX_EDIT_REFS 拉高参考图数量
