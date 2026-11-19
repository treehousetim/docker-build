<?php
// Served by php-fpm during test.sh; proves a worker starts and answers.
echo "fcgi-ok memory_limit=", ini_get('memory_limit'), " sapi=", PHP_SAPI, "\n";
