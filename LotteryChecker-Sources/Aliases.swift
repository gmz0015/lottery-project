import LotteryKit

// `Category` 在 ObjC 运行时(objc/runtime.h)中也有同名 typedef，经 AppKit/Foundation 引入后
// 与 LotteryKit.Category 产生歧义。模块内的本地 typealias 优先于两个被导入的符号，
// 一处声明即可让所有视图直接使用 `Category`。
typealias Category = LotteryKit.Category
