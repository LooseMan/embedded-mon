# Podmanベース Prometheus / Blackbox Exporter / Alertmanager 監視システム構成

Podmanコンテナを活用し、Prometheus・Blackbox Exporter・Alertmanagerを連携させたローカル検証用の外観監視・アラート通知基盤です。

単に設定ファイルを置くだけでなく、「収集・プローブ・通知」の三層の責務を明確に分離した実運用を意識した構造になっています。

---

## 🏗 システムアーキテクチャ・処理フロー


```

[ 監視対象 (SSH 22/TCP等) ]
▲
│ 1. 外観チェック (TCP/HTTP/SSH等)
[ Blackbox Exporter ]
▲
│ 2. メトリクス収集 (/probe)
[ Prometheus ]
│ 3. アラート評価・発火
▼
[ Alertmanager ]
│ 4. グルーピング・テンプレート整形・通知
▼
[ Webhook / Slack等 ] (検証用レシーバー)

```

1. **プローブ処理**: Blackbox Exporter が対象ポート（SSH 22/TCP など）の導通を“外から”確認。
2. **メトリクス収集**: Prometheus が Blackbox Exporter の `/probe` エンドポイント経由で結果をスクレイプ。
3. **ルール評価**: Prometheus 上で定義したルールに基づき、異常発生時にアラートを発火（Pending / Firing）。
4. **通知ルーティング**: Alertmanager がアラートを受信し、重複抑制・グループ化を実施。
5. **テンプレート展開**: Alertmanager 側のテンプレートエンジンにより、人間が読みやすい文面へ整形して送信。

---

## 🧩 各コンポーネントの役割と構成ファイル

### 1. Prometheus (メトリクス収集・ルール評価基盤)
* **役割**: メトリクスの定期収集、アラートルールの評価、Alertmanagerへの送信。
* **関連ファイル**: `prometheus.yml`, `alerts.yml`
* **ポイント**: 
  * UI（`/alerts`）上ではルール定義内のテンプレート変数（例: `{{ $labels.instance }}`）がそのまま表示されますが、これは最終的な変数展開の責務を Alertmanager 側に委ねているためです。

### 2. Blackbox Exporter (外観監視プローブ層)
* **役割**: 外部から HTTP/TCP/SSH 等のネットワーク導通状態を監視。
* **関連ファイル**: `blackbox/blackbox.yml`
* **ポイント**: 
  * Prometheus 単体では行えないネットワーク階層での外部導通チェックを担当。Prometheus は本エクスポーターが生成したメトリクスを収集します。

### 3. Alertmanager (通知・文面整形・ルーティング層)
* **役割**: アラートの受信、グループ化、重複抑制（Inhibit）、通知テンプレートの適用および各種レシーバーへの配信。
* **関連ファイル**: `alertmanager/alertmanager.yml`, `alertmanager/templates/default.tmpl`
* **ポイント**: 
  * 現在の構成では検証用として Webhook 宛先を `127.0.0.1:9099` に設定しています。通知文面のカスタマイズ（Golang template）動作の検証が可能です。

### 4. 起動スクリプト (セットアップ自動化)
* **役割**: コンテナの起動およびネットワーク・ボリュームマウントの接続整理。
* **関連ファイル**: `setup-monitoring.sh`
* **ポイント**: 
  * Podman を使用して各コンポーネントをワンコマンドで立ち上げ・連携させる環境構築ラッパーです。

---

## 🚀 立ち上げ手順

```bash
# 監視環境の起動
bash setup-monitoring.sh

```

---

## 💡 本構成における技術的ポイント・学び

* **コンポーネント間における責務の分離**
* 「メトリクスを測る（Blackbox）」「集めて評価する（Prometheus）」「通知を整形して届ける（Alertmanager）」という一連のライフサイクルを分離して設計・検証しています。


* **テンプレート変数のライフサイクル理解**
* Prometheus 側のルール定義に含まれる `$labels` などの変数が、どのコンポーネント（Alertmanager）で評価・置換されて人間が読める通知（Person-friendly text）に変換されるかという処理パイプラインのフローを考慮して構成しています。
