# 【Catlike Coding Custom SRP学习之旅——5】Baked Light
#### 写在前面
在实时渲染管线中，为了达到更好的性能与表现效果，可以利用光线烘培来非实时地预计算并生成LightMap等光照信息，降低实时光计算量来潜在地提高性能。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 