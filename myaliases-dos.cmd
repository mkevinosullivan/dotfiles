@REM To add these aliases, simply run this file in your command prompt.
@REM Example: C:\> call myaliases-dos.cmd
doskey git_proxy_on=git config --global http.proxy http://198.161.14.25:8080
doskey git_proxy_off=git config --global --unset http.proxy