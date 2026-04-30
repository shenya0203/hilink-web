### 看门狗配置
    看门狗使用 TPS3823 芯片，
    看门狗控制脚是 I2C_SDI 默认配置为I2S 高阻态（悬空） 时禁用看门狗
    正常启动运行时，需要 开启看门狗，当升级时 需要关闭看门狗 防止升级时未及时喂狗导致升级异常
    测试看门狗：
        mem 0x10000060 0x50154444;while true;do gpioset gpiochip0 0=1;sleep 1;gpioset gpiochip0 0=0;sleep 1;done

        sh -c 'echo $$ > /var/run/my_gpio_blink.pid; while true; do gpioset gpiochip0 0=1; sleep 1; gpioset gpiochip0 0=0; sleep 1; done' &
