# GER BULLET EDIT SIMULATOR
https://diaphragm.github.io/gebesim/

## これなに
PSP/PSVita/PS4のアクションゲーム[GOD EATERシリーズ](http://godeater.jp/)に登場する、自由にモジュールを組み合わせてオリジナルのバレットを作成するシステムの弾道シミュレーターです。

## Opal
プログラムはjavascriptですが、rubyで書いたスクリプトを[Opal](http://opalrb.org/)でjavascriptに変換しています。

## THREE.js
ブラウザ上での3D表示には[three.js](http://threejs.org/)を使用しています。

## 更新履歴
- ver.0.1 (2015/11/14)
  - 公開
- ver.0.2 (2015/11/21)
  - BUlletModuleでフレーム毎のmatrixをメモ化。少し動作が早くなった
  - "弾丸:重力の影響を受ける(β)"を追加。重力加速度の測定がうまくいかないためβ扱い。1秒後程度なら大丈夫だがフレームが進むごとに乖離していく。
  - "弾丸:湾曲/近くで""弾丸:湾曲/中間で(β)""弾丸:湾曲/遠くで(β)"を追加。中間でと遠くでに関しては弾道のデータが上手く測定できず実機とズレが生じるためβ
