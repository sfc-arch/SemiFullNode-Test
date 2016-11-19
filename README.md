# README

# sfc-arch/semi-fullnode

forked from [ndac-todoroki/SemiFullNode-Test](https://github.com/ndac-todoroki/SemiFullNode-Test)

ORFでの展示用

1. プロジェクトを複製(cloneとは別に)
2. もうひとつの方で先に `rackup sync.ru -E production`
3. 最初のリポジトリrootに戻ってきて `rails neo4j:install && rails neo4j:start`
4. `rails db:create && rails db:migrate`
5. `rails s` して localhost:3000 にアクセス
6. `rails runner runner/test.rb` して様子を見る
