# php-stack — inspect or redo the current project's Stack record.
#
#   php-stack [status]   show the record and what detection would say now
#   php-stack redetect   drop the record and re-run first-call detection
function php-stack --description 'Inspect or redetect the project Stack record'
    set -l root (__php_stack_root)

    switch "$argv[1]"
        case '' status
            if test -z "$root"
                echo "php-stack: not inside a PHP project (no compose file, composer.json, or artisan found upward of $PWD)"
                return 1
            end
            echo "project: $root"
            if __php_stack_read $root
                set -l line "record:  stack=$__php_stack_stack"
                test -n "$__php_stack_service"; and set line "$line service=$__php_stack_service"
                test -n "$__php_stack_file"; and set line "$line file=$__php_stack_file"
                echo $line
            else
                echo "record:  none (first artisan/composer call will detect)"
            end
            set -l running_file (__php_stack_running_config $root)
            if test -n "$running_file"
                echo "reality: running compose project launched from $running_file → docker"
            else if __php_stack_compose_file $root >/dev/null
                echo "reality: compose file present → docker"
            else if test (count (__php_stack_compose_variants $root)) -gt 0
                echo "reality: non-canonical compose file(s) present → docker (file picked at first call)"
            else
                echo "reality: no compose file → local"
            end
            if not command -q php
                echo "php:     not installed (optional dependency) — add it with 'dotfish install --with-deps php-stack'"
            end
        case redetect
            if test -z "$root"
                echo "php-stack: not inside a PHP project" >&2
                return 1
            end
            __php_stack_detect $root; or return 1
            if test "$__php_stack_stack" = docker
                echo "php-stack: stack=docker service=$__php_stack_service"
            else
                echo "php-stack: stack=local"
            end
        case '*'
            echo "usage: php-stack [status|redetect]" >&2
            return 2
    end
end
