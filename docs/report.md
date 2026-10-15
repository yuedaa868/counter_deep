# counter_deep 改造报告

本报告对应作业的三个步骤，记录改动点、验证方式与"AI 辅助复现"中"先猜后对照"的差异。

- 步骤一（Widget 树）：见 [widget_tree.svg](./widget_tree.svg)
- 步骤二（步长 & 主题）：见下
- 步骤三（生命周期日志 & 资源图片）：见下

---

## 步骤一：Widget 树图

`docs/widget_tree.svg`，由 `lib/main.dart`（flutter create 默认计数器模板）逐层展开，
每个节点标注真实父类。标注结论来自 **Flutter SDK 源码**核对，而非凭记忆
（SDK 路径 `C:\src\flutter\packages\flutter\lib\src`）：

| Widget | 源码声明 | 结论 |
| --- | --- | --- |
| `MyApp` | `lib/main.dart` | StatelessWidget（根，`runApp`） |
| `MaterialApp` | `material/app.dart` | **StatefulWidget**（框架内部） |
| `MyHomePage` | `lib/main.dart` | **StatefulWidget** |
| `_MyHomePageState` | `lib/main.dart` | 不是 Widget，是 `State<MyHomePage>`，持有 `_counter` |
| `Scaffold` | `material/scaffold.dart` | **StatefulWidget**（框架内部） |
| `AppBar` | `material/app_bar.dart` | **StatefulWidget**（框架内部） |
| `Center` | `widgets/basic.dart`：`Center extends Align` | RenderObjectWidget，**既非 Stateless 也非 Stateful** |
| `Column` | `widgets/basic.dart`：`Column extends Flex` | RenderObjectWidget，**既非 Stateless 也非 Stateful** |
| `Text` / `Icon` / `FloatingActionButton` | `widgets/text.dart` / `icon.dart` / `material/floating_action_button.dart` | StatelessWidget |

容易记错的两点：

1. `Scaffold`、`AppBar`、`MaterialApp` 都是 StatefulWidget，不是 StatelessWidget。
2. `Center` / `Column` 这类布局 Widget 继承的是 `RenderObjectWidget`（超类是
   `Widget` 而非 `StatelessWidget`），它们直接建 RenderObject，没有 `State`。
   日常口语里会说它们"无状态"，但严格讲不等于 `StatelessWidget`。

---

## 步骤二：步长与主题

### 2.1 我的第一遍猜想（先写下来，再对照）

拿到需求"每点 +2 或弹层选步长 1/2/5 + 主题改 teal"，我猜要改 4 处：

1. `theme` 里的 `seedColor`：`Colors.deepPurple` → `Colors.teal`。
2. 在 `State` 里加一个 `_step` 字段，把 `_counter++` 改成 `_counter += _step`。
3. 加一个选步长的入口（AppBar 按钮弹层，或干脆写死 +2）。
4. 可能需要改 `pubspec.yaml`（不确定）。

### 2.2 对照方案（AI 给出的完整方案）

对照方案给到 7 个改动点：

| # | 位置 | 改动 |
| --- | --- | --- |
| 1 | `MyApp.build` → `ThemeData.colorScheme` | `ColorScheme.fromSeed(seedColor: Colors.deepPurple)` → `Colors.teal` |
| 2 | `_MyHomePageState` | 新增 `int _step = 1;` |
| 3 | `_incrementCounter` | `_counter++` → `_counter += _step;` |
| 4 | `_MyHomePageState` | 新增 `Future<void> _chooseStep()`：用 `showModalBottomSheet<int>` 列 1/2/5，`Navigator.pop(context, value)` 回传，`await` 后先判 `mounted` 再 `setState` |
| 5 | `AppBar` | 加 `actions: [IconButton(Icons.tune, onPressed: _chooseStep)]` |
| 6 | `body` 的 `Column` | 加 `Text('步长：+$_step / 次')` 显示当前步长 |
| 7 | `FloatingActionButton.tooltip` | `'Increment'` → `'Increment by $_step'` |

### 2.3 差异比较（重点）

| 对比项 | 我的猜想 | 对照方案 | 差异说明 |
| --- | --- | --- | --- |
| 主题种子色 | 命中 | 一致 | 但题面说"默认蓝"，**当前模板其实是 `deepPurple`**，题面与模板版本不符 |
| 步长字段 / 增量 | 命中 | 一致 | `_counter += _step` |
| 选步长 UI | 只写了"加个按钮" | 给出完整实现 | **猜想太粗**：没写出"弹层返回值 + `await` 后 `mounted` 检查"，这是最关键的一处坑 |
| 显示当前步长 | 没想到 | 有 | 少了它就无法直观验证"步长真的生效" |
| FAB tooltip 跟随步长 | 没想到 | 有 | 细节，但影响体验一致性 |
| 弹层里标记当前选中项 | 没想到 | 有（`Icons.check`） | 细节完善 |
| `pubspec.yaml` | 以为要改 | 不用改 | 步长/主题都是纯 Dart 代码，不加依赖、不加资源 → 我的猜想是多余的 |

结论：猜想的"骨架"（主题 + 字段 + 增量）是对的，但漏掉了**异步 UI 的写法**
（`showModalBottomSheet` + `mounted`）和**验证/体验细节**。这说明对照的价值主要在
"具体实现与边界情况"，而不在"改哪几个文件"。

另外发现：该版本模板用了 Dart 的点简写（`.fromSeed` / `.center`），我在改动处
改成了显式写法 `ColorScheme.fromSeed(...)`，可读性更直接。

### 2.4 验证

- `flutter test`（模板自带冒烟测试）通过 → 编译无误、点击 FAB 仍能自增。
- 临时补测（已删除）：断言 `theme.colorScheme.primary == ColorScheme.fromSeed(seedColor: Colors.teal).primary`
  → teal 主题生效；打开弹层选"步长 5"后连点两次 FAB，计数为 `10`
  → 步长选择 + 增量生效。
- 说明：本机 `flutter analyze` 因中文路径导致 analysis server 的 JSON 通道报
  `FormatException` 而崩溃，改用 `flutter test` 作为编译/行为验证手段。

---

## 步骤三：生命周期日志与资源图片

### 3.1 State 生命周期日志

在 `_MyHomePageState` 的每个钩子里加了一行 `print`（入口 `MyHomePage.createState` 也加了一行）。
收集到的钩子与触发时机：

| 钩子 | 触发时机 | 是否被触发 |
| --- | --- | --- |
| `createState()` | 框架第一次需要这个 State 时 | 是（第 1 行） |
| `initState()` | State 插入树，只调用一次 | 是（第 2 行，适合做一次性初始化） |
| `didChangeDependencies()` | 依赖的 `InheritedWidget` 变化后 | 是（第 3 行） |
| `build()` | 每次重建 | 是（首次 + `setState` 后各一次） |
| `didUpdateWidget()` | 父级传下**新的** widget 配置时 | 未触发（本页父级没有再构造 `MyHomePage`） |
| `deactivate()` | State 暂时离开树 | 是 |
| `dispose()` | State 永久销毁 | 是 |

实测输出（临时测试里打印，测试通过后已删除该临时文件）：

```text
[lifecycle] createState()：框架第一次需要 State 时调用，返回 _MyHomePageState
[lifecycle] initState()：State 插入树中，只调用一次（适合做一次性初始化）
[lifecycle] didChangeDependencies()：所依赖的 InheritedWidget 变化后调用
[lifecycle] build()：重建中，当前 _counter=0, _step=1
[lifecycle] build()：重建中，当前 _counter=1, _step=1
[lifecycle] deactivate()：State 暂时离开树（随后可能被重新插入，也可能进入 dispose）
[lifecycle] dispose()：State 永久销毁，在这里释放资源
```

注意两点：

1. `build()` 打印了两次，`initState()` 只打印一次 —— 说明**重建不等于重新创建 State**：
   `_counter` 不会因为重建而清零，`initState` 也不会重跑。
2. `didUpdateWidget` 没出现是正常的，它只在**父级传下来的 widget 配置变化**时才调用；
   本页的父级是 `MyApp`，`MyHomePage` 是 `const` 构造且不会重新创建，所以不触发。

> 用 `print` 是照作业字面要求。正式项目里更推荐 `debugPrint`：它是 lint 友好的写法
> （Flutter 默认 lint 里有 `avoid_print`），并且输出不会阻塞 UI 线程。

### 3.2 assets 自定义图片

- 图片：`assets/images/appbar_bg.jpg`（2560×1440，teal 渐变的抽象波浪，AI 生成）。
- `pubspec.yaml` 里声明：

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

- 用图位置：`AppBar.flexibleSpace`

```dart
flexibleSpace: Image.asset(
  'assets/images/appbar_bg.jpg',
  fit: BoxFit.cover,                          // 自动裁剪填满
  color: Colors.black38,                      // 压暗，保证标题可读
  colorBlendMode: BlendMode.darken,
),
foregroundColor: Colors.white,
```

### 3.3 验证

- 临时测试（已删除）断言 `AssetImage.assetName == 'assets/images/appbar_bg.jpg'`，
  并用 `rootBundle.load('assets/images/appbar_bg.jpg')` 读出字节数 > 0
  —— 说明资源已被打进包。
- `flutter run -d windows` **重启运行**，AppBar 顶部正常显示该图片，控制台按顺序打印生命周期日志。

---

## 检查点：点 FAB 后发生了什么

一句话版：`setState` → 把当前 State 对应的 Element 标记为 dirty → 框架调度下一帧 →
下一帧里重建（重新跑 `build()`）→ 新 Widget 替换旧 Widget → 屏幕刷新。

展开版（对照源码里的名字）：

1. 手势命中 `FloatingActionButton`，触发它的 `onPressed`，也就是 `_incrementCounter()`。
2. `setState(() { _counter += _step; })` 做两件事：
   - 先同步执行传入的闭包，改掉 `_counter`（这一步是"状态变了"）；
   - 再调用 `_element.markNeedsBuild()`，把该 Element 放进 `BuildOwner` 的 dirty 列表。
3. 此时**不会立刻重建**。dirty 只是在"排队"，UI 要等下一帧。
4. 下一帧 `drawFrame` 阶段，`BuildOwner.buildScope` 遍历 dirty 列表，
   调用 `element.rebuild()`，也就是重新执行 `_MyHomePageState.build()`。
5. `build()` 返回的是一棵**新的** Widget 树。Widget 是 immutable 的"配置"，
   Element 才是长期存在、承载状态的对象：框架拿新 Widget 去更新旧 Element，
   真正变化的是底层 `RenderObject` 的属性和布局，再交给渲染管线。
6. 引擎把新的 layer tree 光栅化上屏，数字就变了。

两个容易混淆的点：

- "重建"重建的是 **Widget 树**，不是 Element / State。所以 `_counter` 不会清零，
  `initState` 不会重跑（这正是热重载不丢状态、而热重启会丢状态的原因）。
- 如果只写 `_counter += _step;` 而不包 `setState`，值确实变了，
  但没有 Element 被标 dirty，下一帧不会重建，**屏幕上什么都不会变**。

### 检查点自检结果

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| 步长与主题功能正确 | 通过 | 临时测试：teal 主题断言通过；选"步长 5"后连点两次 FAB 计数为 10 |
| 生命周期日志齐全 | 通过 | 7 条 `[lifecycle]` 日志按 `createState → initState → didChangeDependencies → build → (setState) build → deactivate → dispose` 顺序打印 |
| 资源图片正常显示 | 通过 | `rootBundle.load` 读到字节；`flutter run -d windows` 重启后 AppBar 顶部显示图片 |
| 解释点 FAB 的流程 | 通过 | 见上一节 |

> 环境备注：本机 `flutter analyze` 因项目路径含中文，导致 analysis server 的
> JSON 通道报 `FormatException`（`Unterminated string`）而崩溃。因此本项目
> 用 `flutter test`（会先编译 `lib/`）作为编译与行为验证手段。

