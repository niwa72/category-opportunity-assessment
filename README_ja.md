# カテゴリ機会分析 — Shopee Thailand

## 1. プロジェクト概要

**このプロジェクトを選んだ理由**

SQLのスキルを見せるだけではなく、実務に近い形でビジネス分析を進めるプロセスをポートフォリオとして残したいと考えました。  
最初から決められた問いに対して数本のSQLを書くのではなく、曖昧なビジネス課題を整理し、指標の定義を決め、データで前提を検証しながら、事実と解釈を分けて考えるところまでを分析の対象にしています。

**ビジネス背景**

複数カテゴリを扱うECプラットフォームでは、「今後どのカテゴリに注目すべきか」は継続的に考える必要があるテーマです。  
ただし、1つの指標だけでは判断できません。顧客リーチ、成長、再購入行動、キャンペーンとの関係など、それぞれ異なる側面から見る必要があります。

**データセット**

本プロジェクトでは、Shopee Thailand Customer Journey & Operations Dataset を使用しています。  
顧客、注文、注文明細、商品、キャンペーン、商品キャンペーン、出店者、配送、Web/セッション行動など、11個のCSVテーブルで構成されたデータセットです。

分析ではまず `orders`、`order_items`、`products` を結合し、注文明細単位の `analysis_base` を作成しました。  
そのうえで、キャンペーン関連テーブルを使い、各カテゴリの売上とキャンペーンの関連度を確認しています。

**確認したかったこと**

5つのカテゴリ（Home / Groceries / Electronics / Fashion / Beauty）を、次の3つの観点から比較しました。

- **Demand** — 現在の顧客リーチと時間軸での動き
- **Continuation** — あるカテゴリを初めて購入した顧客が、その後180日以内にプラットフォーム上で再購入したか
- **Campaign association** — カテゴリ売上のうち、特定可能なキャンペーンと関連している売上がどの程度あるか

目的はカテゴリを単純に1位から5位までスコアリングすることではなく、今後さらに検討する価値のある特徴的なシグナルを見つけることです。

**スコープ**

分析対象は、上記3つの購買・商流に関する観点に絞りました。  
収益性、外部市場規模、競合状況、越境ECとしての実現可能性については、このデータだけでは十分に判断できないため、次の検証項目として扱っています。

---

## 2. ビジネス課題

**メインの問い**

Shopee Thailand 上のどのカテゴリが、越境展開をさらに検討するうえで有望な購買行動シグナルを示しているか？

**補助的な問い**

これらのシグナルを市場判断につなげる前に、どのようなデータ上の制約やリスクを認識しておく必要があるか？

**この問いにした理由**

今回使用しているのは、プラットフォーム内部の取引データのみです。  
外部市場規模、競合状況、消費者調査などのデータは含まれていません。

そのため、このデータから確認できるのは、購買パターン、売上集中度、顧客の継続購入といった**シグナル**であり、市場全体の規模や魅力度を確定することはできません。  
分析では、データから実際に言える範囲を超えないように、問いそのものも限定しています。

また、地域別ではなくカテゴリ別を主軸にしました。  
商品属性、キャンペーン関連度、再購入行動などはカテゴリ単位で比較しやすい一方、都道府県・地域レベルでは十分な情報が揃っていなかったためです。

---

## 3. データとツール

- **Dataset:** Shopee Thailand Customer Journey & Operations Dataset — EC取引・カスタマージャーニーを模した11個のCSVテーブル
- **Core analytical tables:** `order_items`、`orders`、`products` を結合し、注文明細単位の `analysis_base` を作成
- **Campaign analysis:** `order_items` の `is_campaign` と `product_campaign_id` からキャンペーン状態を分類。参照用キャンペーンテーブルも整合性確認に使用
- **Validation:** `shipments` を使い、どの注文ステータスを実績購入として扱うべきかを確認。その結果、3つの分析すべてで Completed のみを使用
- **除外したテーブル:** `reviews`、`website_sessions` / `session_activities`。レビューには評価点がなく、利用するにはNLP分析が必要になるため対象外。セッションデータはファネルの整合性確認にのみ使用
- **期間:** 2022年1月〜2025年12月
- **規模:** 約48万件の注文明細、約30万件の注文、約4,880商品、5カテゴリ
- **SQL:** MySQL — CTE、Window Function、JOIN、相関サブクエリ
- **分析範囲:** カテゴリ需要、顧客継続、キャンペーン関連度の3点に限定。利用可能だからという理由だけで他のデータを追加することはしていません

---

## 4. 分析アプローチ

**分析基盤**

分析のベースは、`order_items`、`orders`、`products` の3テーブルを結合した `analysis_base` です。  
分析時には `item_status = 'Completed'` のみを対象とし、Cancelled（約20%）と Refunded（約5%）は除外しています。

購入意向ではなく、実際に成立した購買行動を見るためです。

**3つの分析観点**

各カテゴリを、次の3つの観点で比較しました。

**Demand** — カテゴリ別の売上とユニーク顧客数を確認し、さらに絶対的な売上成長ではなく、年間のプラットフォーム浸透率（カテゴリ顧客数 ÷ 全アクティブ顧客数）を使用しました。  
2022年から2025年にかけてプラットフォーム全体が約6.6倍に成長しているため、カテゴリ売上が増えていても、プラットフォーム全体より遅い場合は相対的な存在感が低下している可能性があるためです。

**Continuation** — 各カテゴリを初めて購入した顧客が、その後180日以内にもう一度購入した割合を確認しました。  
180日は任意に決めた期間ではなく、実データの購入間隔分布（中央値94日、75パーセンタイル185日）を確認したうえで設定しています。

**Campaign Sensitivity** — カテゴリ売上のうちキャンペーンと関連する売上の割合を、lower bound / identifiable / upper bound の3点で確認しました。  
キャンペーンフラグがある一方でキャンペーンIDまで追えない取引が存在するため、単一の値に決めずレンジとして扱っています。  
これはあくまで観測されたキャンペーン関連度であり、キャンペーン効果やオーガニック需要を証明するものではありません。

3つを組み合わせて見たのは、1つの指標だけではカテゴリの違いを十分に説明できなかったためです。  
たとえば、規模の大きいカテゴリでも継続率が高いとは限らず、小規模なカテゴリでもキャンペーンとの関連が比較的低い場合があります。

---

## 5. 主な分析結果

**Demand — カテゴリによって規模と顧客価値が大きく異なる**

Home は顧客数（50,883人）、総売上（¥1.9B）の両方で最大で、顧客1人あたり売上は ¥37,454 でした。  
Electronics は顧客数が32,376人と Home より約36%少ない一方、売上は ¥1.0B、顧客1人あたり売上は ¥31,939 です。

一方 Groceries は、顧客数38,168人と2番目に大きいにもかかわらず、総売上は約¥15M、顧客1人あたり売上は ¥400 にとどまります。

つまり、顧客リーチが広いことと、カテゴリとしての売上価値が高いことは同じではありません。

**Continuation — カテゴリ間の差はほとんどない**

180日以内の継続率は、Home の61.31%から Electronics の62.77%までで、5カテゴリすべて非常に近い結果でした。  
最大差は1.5ポイント未満です。

そのため、このデータでは継続率をカテゴリ選定の決め手としては扱わず、補足情報として捉えています。

**Campaign Sensitivity — 特定可能なキャンペーン関連度には差がある**

特定可能なキャンペーン関連売上の比率は、Beauty の1.45%から Groceries の3.20%まででした。  
Electronics（1.80%）と Home（1.73%）も比較的低い水準です。

この結果から言えるのは、Beauty、Electronics、Home の観測売上は、データ上で追跡可能なキャンペーンとの関連が比較的低かったということです。  
ただし、キャンペーン帰属データは完全ではないため、残りがすべてオーガニック需要だったと判断することはできません。

**カテゴリ横断で見た示唆**

越境ECの観点では、Groceries は顧客1人あたり売上が ¥400 と低いため、物流コストとのバランスをまず確認する必要があります。  
このデータには実際の物流コストが含まれていないため、「不向き」と結論づけるのではなく、追加検証が必要なポイントと捉えています。

Electronics と Beauty については、キャンペーン関連度が比較的低いという別の観点から、追加で確認する価値があります。

---

## 6. ダッシュボード

![Category Opportunity Assessment Dashboard](visuals/dashboard_preview.png)

[Tableau Public でインタラクティブダッシュボードを見る](https://public.tableau.com/app/profile/niwadee.khommee/viz/CategoryOpportunityAssessment-ShopeeThailand/1)

ダッシュボードでは、Demand、180日以内の顧客継続、Campaign association の3つをまとめて比較しています。

---

## 7. カテゴリ別シグナル

| Category | Customers | Total Revenue | Rev/Customer | Continuation (180d) | Campaign Share (identifiable) | Signal Summary |
|---|---:|---:|---:|---:|---:|---|
| Home | 50,883 | ¥1,905,768,258 | ¥37,454 | 61.31% | 1.73% | 需要規模・顧客価値ともに高く、キャンペーン関連度は低い |
| Electronics | 32,376 | ¥1,034,049,408 | ¥31,939 | 62.77% | 1.80% | 顧客価値が高く、継続率は最も高いが差は小さい。キャンペーン関連度も低い |
| Fashion | 20,778 | ¥87,826,012 | ¥4,227 | 62.53% | 2.67% | 3つの観点で中間的な位置 |
| Groceries | 38,168 | ¥15,249,827 | ¥400 | 62.26% | 3.20% | 顧客リーチは広いが顧客価値は非常に低く、キャンペーン関連度は最も高い |
| Beauty | 12,005 | ¥12,407,558 | ¥1,034 | 62.61% | 1.45% | 顧客基盤は最小だが、特定可能なキャンペーン関連度も最も低い |

**シグナルの読み方**

- **Home / Electronics** — 売上規模が大きく、特定可能なキャンペーン関連度は比較的低い。継続率は他カテゴリと大きな差がない
- **Beauty** — 顧客基盤は小さいが、特定可能なキャンペーン関連度は最も低い
- **Fashion** — 3つの観点のいずれでも極端な特徴は見られない
- **Groceries** — 顧客リーチは広い一方、顧客1人あたり売上が非常に低い。キャンペーン関連度と越境ECとしての採算性は追加検証が必要

---

## 8. 次に検証したいカテゴリ

**Electronics と Beauty**

今回のプラットフォーム内部データだけを見ると、次の越境EC検討フェーズで優先的に確認したいのは Electronics と Beauty です。  
ただし、これは市場参入の意思決定ではなく、あくまで「次に詳しく調べる候補」です。

**Electronics**

Electronics が目立つのは、主に顧客価値です。  
比較的大きな顧客基盤を持ちながら、顧客1人あたり売上は ¥31,939 です。

継続率は5カテゴリで最も高い62.77%ですが、他カテゴリとの差が小さいため、強い差別化要因とは考えていません。  
一方、特定可能なキャンペーン関連度は1.80%と低めです。

そのため、次のステップでは外部市場規模、競争環境、物流条件と組み合わせて検証する価値があると考えています。

**Beauty**

Beauty は別の理由で気になるカテゴリです。  
顧客数は12,005人と最小であり、現時点の需要規模は限定的です。

一方で、特定可能なキャンペーン関連度は5カテゴリで最も低い1.45%でした。  
これだけでオーガニック需要が強いとは言えませんが、規模が小さいという理由だけで除外する前に、外部市場需要や競争環境を確認する価値はあります。

**今回優先しなかったカテゴリ**

Home は絶対売上が最も大きいため、物流や収益性データが得られれば今後も検討対象になります。  
Fashion は今回使用した3つの観点では、特に際立った特徴がありませんでした。

Groceries は顧客数が多い一方、顧客1人あたり売上が ¥400 と低いため、まず物流採算性と商品構成を確認する必要があります。

**重要な前提**

この判断は、Shopee Thailand のプラットフォーム内部シグナルだけに基づいています。

実際の市場判断には、外部市場規模、競合状況、規制、物流条件、消費者調査など、追加の検証が必要です。  
今回の分析は「どこに投資すべきか」を決めるものではなく、「次にどこを詳しく見るか」を絞り込むためのものです。

---

## 9. 制約・注意点

**プラットフォーム内部データのみ**

今回の分析は Shopee Thailand の取引データのみを使用しています。  
外部市場規模、競合動向、消費者調査、マクロ経済データは含まれていません。

そのため、結果はプラットフォーム内の購買行動を示すものであり、タイ市場全体や越境EC需要全体を示すものではありません。

**因果関係は判断できない**

今回確認できるのは、関連性や購買行動のパターンです。

キャンペーン関連度が低いからといって、オーガニック需要が強いとは限りません。  
また Continuation 指標も、カテゴリへのロイヤルティを示しているのか、単に Shopee 上で買い物を続けているのかまでは判断できません。

そのため、結果は結論ではなく、次の検証につなげるシグナルとして扱っています。

**キャンペーン帰属が不完全**

キャンペーン関連売上は `product_campaign_id` を使って識別しています。  
一方、`is_campaign = 1` であっても特定のキャンペーンIDまで追跡できない取引が一部存在します。

そのため lower / identifiable / upper bound の3点でレンジを示していますが、この方法でも不確実性そのものが解消されるわけではありません。

**180日という観測期間**

180日は、実データの購入間隔分布（75パーセンタイル = 185日）を参考に設定していますが、あくまで分析上の閾値です。

期間を変えれば継続率の値も変わります。  
また、今回の5カテゴリの結果は非常に近いため、順位そのものには重きを置いていません。

**競争環境・物流条件は対象外**

カテゴリごとの競争状況、輸入規制、物流面の実現可能性は、このデータからは判断できません。  
実際の市場参入判断には、これらの情報が必要です。

---

## 10. SQL & Methodology

**概要**

すべてのクエリは MySQL で実行しています。  
分析の共通基盤として、注文明細単位の `analysis_base` を作成し、次の4段階で分析しました。

1. 分析基盤の作成
2. Demand の計測
3. Continuation の計測
4. Campaign association の計測

---

**Stage 1 — 分析基盤の作成**

`order_items`、`orders`、`products` を結合し、共通の分析テーブルを作成します。  
`is_campaign`、`product_campaign_id` もこの段階で保持し、後続の3つの分析で同じ粒度を使用できるようにしています。

```sql
CREATE TABLE analysis_base AS
SELECT
    oi.order_item_id, oi.order_id, o.customer_id, o.order_date,
    oi.product_id, p.category, oi.line_total, oi.item_status,
    oi.is_campaign, oi.product_campaign_id
FROM shopee_order_items_thailand AS oi
LEFT JOIN shopee_orders_thailand AS o ON oi.order_id = o.order_id
LEFT JOIN shopee_products_thailand AS p ON oi.product_id = p.product_id;
```

*すべての分析では `item_status = 'Completed'` のみを使用しています。`shipments` テーブルで確認したところ、Completed は100%配送実績があり、Cancelled / Refunded は0%でした。*

---

**Stage 2 — Demand: Scale and Penetration**

カテゴリごとの顧客リーチと売上を確認したうえで、2022年から2025年にかけたプラットフォーム全体の約6.6倍成長を考慮するため、年間浸透率（カテゴリ顧客数 ÷ 全アクティブ顧客数）を算出しています。

```sql
-- Scale
SELECT category, COUNT(DISTINCT customer_id) AS unique_customers, SUM(line_total) AS revenue
FROM analysis_base WHERE item_status = 'Completed'
GROUP BY category ORDER BY unique_customers DESC;

-- Penetration (year-on-year)
WITH yearly_category_customers AS (
    SELECT category, YEAR(order_date) AS yr, COUNT(DISTINCT customer_id) AS category_customers
    FROM analysis_base WHERE item_status = 'Completed' GROUP BY category, YEAR(order_date)
),
yearly_active_customers AS (
    SELECT YEAR(order_date) AS yr, COUNT(DISTINCT customer_id) AS active_customers
    FROM analysis_base WHERE item_status = 'Completed' GROUP BY YEAR(order_date)
),
penetration AS (
    SELECT c.category, c.yr, c.category_customers, a.active_customers,
           c.category_customers / a.active_customers AS penetration
    FROM yearly_category_customers c JOIN yearly_active_customers a ON c.yr = a.yr
)
SELECT category, yr, category_customers, active_customers, penetration,
       LAG(penetration) OVER (PARTITION BY category ORDER BY yr) AS prior_penetration,
       penetration - LAG(penetration) OVER (PARTITION BY category ORDER BY yr) AS penetration_change
FROM penetration ORDER BY category, yr;
```

---

**Stage 3 — Continuation: 180日以内の再購入**

顧客ごと・カテゴリごとの初回 Completed 購入日を特定し、その後180日以内にカテゴリを問わず再購入があったかを確認しています。

180日分の観測期間が確保できる顧客のみを分母に含めています。

```sql
CREATE TABLE customer_category_first_purchase AS
SELECT customer_id, category, MIN(order_date) AS first_purchase_date
FROM analysis_base WHERE item_status = 'Completed' GROUP BY customer_id, category;

CREATE TABLE customer_category_observation AS
SELECT f.customer_id, f.category, f.first_purchase_date,
       DATE_ADD(f.first_purchase_date, INTERVAL 180 DAY) AS window_end_date,
       CASE WHEN DATE_ADD(f.first_purchase_date, INTERVAL 180 DAY)
                 <= (SELECT MAX(order_date) FROM analysis_base)
            THEN 'eligible' ELSE 'insufficient observation window' END AS observation_status
FROM customer_category_first_purchase f;

CREATE TABLE customer_category_continuation AS
SELECT o.customer_id, o.category, o.first_purchase_date, o.window_end_date, o.observation_status,
    CASE WHEN o.observation_status = 'eligible' THEN
        CASE WHEN EXISTS (
            SELECT 1 FROM analysis_base ab
            WHERE ab.customer_id = o.customer_id AND ab.item_status = 'Completed'
              AND ab.order_date > o.first_purchase_date AND ab.order_date <= o.window_end_date
        ) THEN 1 ELSE 0 END
    ELSE NULL END AS continuation_flag
FROM customer_category_observation o;

SELECT category,
    SUM(observation_status='eligible') AS eligible_pairs,
    ROUND(SUM(continuation_flag=1)*100.0/NULLIF(SUM(observation_status='eligible'),0),2) AS continuation_rate_pct
FROM customer_category_continuation GROUP BY category;
```

---

**Stage 4 — Campaign Association: 3-point sensitivity range**

各注文明細を3つの状態に分類し、キャンペーン追跡の不完全さを考慮して、関連売上比率をレンジで示しています。

```sql
WITH classified AS (
    SELECT category, item_status, line_total,
        CASE WHEN product_campaign_id IS NOT NULL THEN 'campaign-associated'
             WHEN is_campaign = 1 THEN 'campaign-untraceable'
             ELSE 'not campaign-associated' END AS campaign_status
    FROM analysis_base
),
category_revenue AS (
    SELECT category,
        SUM(CASE WHEN item_status='Completed' THEN line_total ELSE 0 END) AS total_completed_revenue,
        SUM(CASE WHEN item_status='Completed' AND campaign_status='campaign-associated' THEN line_total ELSE 0 END) AS campaign_revenue,
        SUM(CASE WHEN item_status='Completed' AND campaign_status='campaign-untraceable' THEN line_total ELSE 0 END) AS untraceable_revenue
    FROM classified GROUP BY category
)
SELECT category,
    ROUND(campaign_revenue / total_completed_revenue * 100, 2) AS lower_bound_pct,
    ROUND(campaign_revenue / NULLIF(total_completed_revenue - untraceable_revenue, 0) * 100, 2) AS identifiable_share_pct,
    ROUND((campaign_revenue + untraceable_revenue) / total_completed_revenue * 100, 2) AS upper_bound_scenario_pct
FROM category_revenue ORDER BY category;
```

---

## 11. このプロジェクトでのAIの使い方

AIは主に、SQL実行の補助、検証、エッジケースの確認に使いました。  
一方で、ビジネス課題の設定、指標定義、解釈の判断は自分で行っています。

このプロジェクトを通して学んだのは、見た目が整った回答でも、データが実際に示している範囲を超えてしまうことがあるということです。

特に、Continuation の観測期間やキャンペーン帰属については、分母を確認し、前提を疑い、解釈を何度か修正しました。

AIによって機械的な作業は速くなりましたが、最終的な分析判断には人による確認が必要でした。
