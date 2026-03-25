// 功能开关配置文件
// 用于集中管理系统的功能特性显示与隐藏

// 默认设备 IP (用于恢复出厂后的重新连接引导)
export const DEFAULT_DEVICE_IP = '192.168.18.254';

// TF卡功能开关
// false: 隐藏TF卡管理界面，并强制禁用依赖TF卡的"断网缓存"功能
// true: 显示TF卡管理界面，允许使用"断网缓存"功能
export const FEATURE_TF_CARD_ENABLED = false;

// 设备型号 (显示在页面右上角)
export const APP_DEVICE_MODEL = 'HLK-N720';
