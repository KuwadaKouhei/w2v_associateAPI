# Git LFS セットアップガイド

## Git LFS とは
Git Large File Storage (LFS) は大容量ファイルをGitで効率的に管理するためのツールです。

## セットアップ手順

### 1. Git LFS インストール
```bash
# Windows (Git for Windows に含まれている場合が多い)
git lfs version

# インストールが必要な場合
# https://git-lfs.github.io/ からダウンロード
```

### 2. リポジトリでLFS有効化
```bash
cd w2v_associateAPI
git lfs install
```

### 3. 大容量ファイルをLFS追跡対象に設定
```bash
# モデルファイルをLFS管理下に
git lfs track "entity_vector/*.txt"
git lfs track "entity_vector/*.bin"
git lfs track "*.model"

# .gitattributes が自動生成される
git add .gitattributes
```

### 4. モデルファイルを追加
```bash
# .gitignore からモデルファイル行を削除
# entity_vector/entity_vector.model.txt
# entity_vector/entity_vector.model.bin

git add entity_vector/
git commit -m "Add model files with Git LFS"
git push origin main
```

## 利用者側での取得
```bash
git clone https://github.com/KuwadaKouhei/w2v_associateAPI.git
cd w2v_associateAPI
git lfs pull  # モデルファイルをダウンロード
```

## 注意点
- GitHub LFS: 月1GB無料、追加は有料
- GitLab LFS: 月10GB無料
- Bitbucket LFS: 月1GB無料