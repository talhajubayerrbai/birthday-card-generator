# 🎂 Birthday Card Generator

A lightweight Flask web app that lets users create personalised birthday cards and share them via a unique URL.

## Features

- Pick a recipient name, sender name, and a card style/colour theme
- Write a custom message (or use the auto-generated one)
- Get a shareable permalink: `/card/<id>`
- Six built-in card styles: Sunshine, Ocean, Rose, Forest, Midnight, Candy
- SQLite persistence — no external database required

## Running locally

```bash
pip install -r requirements.txt
python app.py          # dev server on :5000
# or
gunicorn app:app --bind 0.0.0.0:5000
```

## Project structure

```
.
├── app.py             # Flask application
├── requirements.txt
├── Procfile
├── templates/
│   ├── base.html
│   ├── index.html     # Card creation form
│   ├── card.html      # Card display + share
│   └── 404.html
├── static/
│   └── style.css
└── infra/             # Terraform — EC2 on AWS
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

## Deployment

Deployed to AWS EC2 (`t3.micro`, `us-east-1`) via GitHub Actions + Terraform.
The pipeline is triggered by UDAP on every promotion.
