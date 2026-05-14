# Домашнее задание 10: Пишем скрипт

## Задания
Написать скрипт для CRON, который раз в час формирует отчёт и отправляет его на заданную почту.

Отчёт должен содержать:

IP-адреса с наибольшим числом запросов (с момента последнего запуска);
Запрашиваемые URL с наибольшим числом запросов (с момента последнего запуска);
Ошибки веб-сервера/приложения (с момента последнего запуска);
HTTP-коды ответов с указанием их количества (с момента последнего запуска).

Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.

В письме должен быть прописан обрабатываемый временной диапазон.


## Структура
web-report.sh - скрипт. <br>
README.md - описание ДЗ и ход выполнения.


## Выполнение
### Ставим nginx
```
root@otus-homework:~# apt install -y nginx mailutils shellcheck
root@otus-homework:~# systemctl enable --now nginx
root@otus-homework:~# systemctl status nginx

```

### Создаем скрипт и делаем его исполняемым, письмо будет приходить на root
```
root@otus-homework:~# mkdir -p ~/bash-web-report
root@otus-homework:~# cd ~/bash-web-report
root@otus-homework:~# nano web-report.sh
root@otus-homework:~# chmod +x web-report.sh
root@otus-homework:~# shellcheck web-report.sh
root@otus-homework:~# cp web-report.sh /usr/local/bin/web-report.sh
root@otus-homework:~# chmod +x /usr/local/bin/web-report.sh

 
```

### Добавляем задачу в cron
```
root@otus-homework:~# systemctl status cron

root@otus-homework:~# crontab -e

root@otus-homework:~# crontab -l
# Edit this file to introduce tasks to be run by cron.
# 
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
# 
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').
# 
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
# 
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
# 
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
# 
# For more information see the manual pages of crontab(5) and cron(8)
# 
# m h  dom mon dow   command

0 * * * * /usr/local/bin/web-report.sh


```

### Проверяем работу

```
root@otus-homework:~# mail
"/var/mail/root": 1 message 1 new
>N   1 root               Wed May 13 15:00  35/979   Web server hourly report: 13/May/2026:14:49:34 +0000 - 13/May/2026:14:49:40 +0000
? 1
Return-Path: <root@otus-homework>
X-Original-To: root
Delivered-To: root@otus-homework
Received: by otus-homework (Postfix, from userid 0)
	id 196BAC40BFA; Wed, 13 May 2026 15:00:02 +0000 (UTC)
Subject: Web server hourly report: 13/May/2026:14:49:34 +0000 - 13/May/2026:14:49:40 +0000
To: root@otus-homework
User-Agent: mail (GNU Mailutils 3.17)
Date: Wed, 13 May 2026 15:00:02 +0000
Message-Id: <20260513150002.196BAC40BFA@otus-homework>
From: root <root@otus-homework>

Web server hourly report
========================

Processed time range:
13/May/2026:14:49:34 +0000 - 13/May/2026:14:49:40 +0000

Top IP addresses:
-----------------
      2 194.55.235.242

Top requested URLs:
-------------------
      1 /test
      1 /

HTTP response codes:
--------------------
      1 404
      1 200

Web server/application errors, HTTP 4xx/5xx:
---------------------------------------------
194.55.235.242 - - [13/May/2026:14:49:40 +0000] "GET /test HTTP/1.1" 404 162 "-" "curl/8.7.1"
? q
Saved 1 message in /root/mbox
Held 0 messages in /var/mail/root

```
