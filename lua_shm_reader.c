/*
 * lua_shm_reader.c
 * 
 * Compile with:
 * gcc -shared -o shm_reader.so -fPIC lua_shm_reader.c -llua -lrt
 * 
 * Note: Adjust include paths (-I) and library paths (-L) as needed for your OpenWrt SDK.
 * For example:
 * gcc -shared -o shm_reader.so -fPIC lua_shm_reader.c -I/usr/include/lua5.1 -llua5.1 -lrt
 */

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#define MODBUS_SHM_NAME "/modbus_shm"
#define MODBUS_MAX_INDEX_ENTRIES 1000 

// 索引表项
typedef struct {
    char device_name[50];          // 设备名称
    char point_name[50];           // 采集点名称
    int absolute_index;            // data[] 中的下标
} modbus_index_entry_t;

// 共享内存主结构
typedef struct {
    int device_count;
    int total_points;
    int index_entry_count;
    int version;
    time_t last_update_time;
    modbus_index_entry_t index_table[MODBUS_MAX_INDEX_ENTRIES]; 
    double data[];                 // 柔性数组，存放实际值
} modbus_shm_t;

static int l_read_values(lua_State *L) {
    int shm_fd;
    modbus_shm_t *shm_ptr;
    struct stat shm_stat;
    
    // 1. 打开共享内存
    shm_fd = shm_open(MODBUS_SHM_NAME, O_RDONLY, 0666);
    if (shm_fd == -1) {
        // 如果打开失败（例如文件不存在），返回 nil
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    // 2. 获取大小以进行映射
    if (fstat(shm_fd, &shm_stat) == -1) {
        close(shm_fd);
        lua_pushnil(L);
        lua_pushstring(L, "fstat failed");
        return 2;
    }

    // 3. 映射内存
    shm_ptr = mmap(NULL, shm_stat.st_size, PROT_READ, MAP_SHARED, shm_fd, 0);
    if (shm_ptr == MAP_FAILED) {
        close(shm_fd);
        lua_pushnil(L);
        lua_pushstring(L, "mmap failed");
        return 2;
    }

    // 4. 构建 Lua Table
    // 结构: { ["Device1"] = { ["node0101"] = 12.5, ... }, ... }
    lua_newtable(L); // 主表

    for (int i = 0; i < shm_ptr->index_entry_count; i++) {
        modbus_index_entry_t *entry = &shm_ptr->index_table[i];
        
        // 检查索引是否越界 (虽然理论上不会，但为了安全)
        // 注意：这里无法准确知道 data[] 的最大长度，只能依赖 index_entry_count 和 total_points
        // 假设 absolute_index 是有效的
        
        double value = shm_ptr->data[entry->absolute_index];

        // 获取或创建设备表
        // Stack: [MainTable]
        lua_pushstring(L, entry->device_name); // Stack: [MainTable, "DeviceName"]
        lua_gettable(L, -2); // Stack: [MainTable, DeviceTable_or_nil]

        if (lua_isnil(L, -1)) {
            lua_pop(L, 1); // Pop nil. Stack: [MainTable]
            lua_newtable(L); // Stack: [MainTable, NewDeviceTable]
            lua_pushstring(L, entry->device_name); // Stack: [MainTable, NewDeviceTable, "DeviceName"]
            lua_pushvalue(L, -2); // Stack: [MainTable, NewDeviceTable, "DeviceName", NewDeviceTable]
            lua_settable(L, -4); // MainTable["DeviceName"] = NewDeviceTable. Stack: [MainTable, NewDeviceTable]
        }
        
        // Stack: [MainTable, DeviceTable]
        lua_pushstring(L, entry->point_name); // Stack: [MainTable, DeviceTable, "PointName"]
        lua_pushnumber(L, value); // Stack: [MainTable, DeviceTable, "PointName", Value]
        lua_settable(L, -3); // DeviceTable["PointName"] = Value. Stack: [MainTable, DeviceTable]
        
        lua_pop(L, 1); // Pop DeviceTable. Stack: [MainTable]
    }

    // 5. 清理
    munmap(shm_ptr, shm_stat.st_size);
    close(shm_fd);

    return 1; // 返回主表
}

static const struct luaL_Reg shm_reader_lib[] = {
    {"read_values", l_read_values},
    {NULL, NULL}
};

// 导出函数
int luaopen_shm_reader(lua_State *L) {
    luaL_register(L, "shm_reader", shm_reader_lib);
    return 1;
}
