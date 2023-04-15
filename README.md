# sw-test-resplen
sw-test-resplen は、Stormworks の HTTP 機能で受信できるレスポンスの最大データ長を検証するためのツールです。

## 検証結果
- 約 633 KiB 未満のレスポンスは問題なく受信できます。
- 約 633 KiB を超えるレスポンスは受信が間に合わずタイムアウトします。
  - `httpReply` の `reply` 引数に `"timeout"` が渡されます。
  - タイムアウトは5秒のようです。
- タイムアウト有無の閾値は検証する度にランダムに変わります。
  - おおよそ 631 ~ 635 KiB の範囲でランダムとなります。
  - この閾値はマシンの性能差などによって変わるかもしれません。

前提条件
- Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz (x64)
- GeForce GTX 1050/PCIe/SSE2 4.6.0 NVIDIA 457.51
- 8192MB RAM
- Windows 10 Home 10.0 64bit
- go version go1.20.3 windows/amd64
- Stormworks 64-bit v1.7.2
- シングルプレイ
- Search and Destroy DLC 有効
- Industrial Frontier DLC 有効
- アドオンの HTTP 機能で検証
- 検証用アドオン以外のすべてのアドオンは無効
- 新規作成直後のワールドで検証
- O'Neill Airbase のベッド付近で検証

## 検証ツールの使い方
本リポジトリには、検証で使用するアドオンと HTTP サーバーのソースコードが含まれます。

### 検証用アドオン
検証用アドオンは、`addon/test_resplen` に格納されています。
