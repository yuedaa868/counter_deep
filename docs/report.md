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

（待补）

---

## 检查点：点 FAB 后发生了什么

（待补）
