// ==========================================
// HybridOS - Virtual File System (Fixed)
// ==========================================

// Types de base
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long size_t;
#define NULL ((void*)0)
#define true 1
#define false 0
typedef int bool;

// VGA
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
static uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;

// Terminal state
static size_t term_row = 0;
static size_t term_col = 0;
static uint8_t term_color = 0x07;
static char input_buffer[256];
static char current_path[256] = "/";

// ==================== FILE SYSTEM STRUCTURES ====================
#define MAX_FILENAME 32
#define MAX_FILES 128
#define MAX_FILE_SIZE 4096
#define MAX_PATH 256

typedef enum {
    FS_FILE = 1,
    FS_DIRECTORY = 2
} fs_node_type;

typedef struct fs_node {
    char name[MAX_FILENAME];
    fs_node_type type;
    size_t size;
    char* content;
    struct fs_node* parent;
    struct fs_node* children[MAX_FILES];
    int child_count;
    // Metadata
    uint32_t created_time;
    uint32_t modified_time;
    uint8_t permissions;
} fs_node_t;

// File system globals
fs_node_t* fs_root;
fs_node_t* current_dir;
fs_node_t fs_nodes[MAX_FILES];
int fs_node_count = 0;
char file_data_pool[MAX_FILES * MAX_FILE_SIZE];
int file_data_used = 0;

// ==================== FORWARD DECLARATIONS ====================
fs_node_t* fs_find_child(fs_node_t* parent, const char* name);
fs_node_t* fs_resolve_path(const char* path);
void fs_get_path(fs_node_t* node, char* buffer);

// ==================== I/O FUNCTIONS ====================
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// ==================== STRING FUNCTIONS ====================
size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len]) len++;
    return len;
}

int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++; s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

void strcpy(char* dest, const char* src) {
    while (*src) {
        *dest++ = *src++;
    }
    *dest = '\0';
}

void strcat(char* dest, const char* src) {
    while (*dest) dest++;
    while (*src) {
        *dest++ = *src++;
    }
    *dest = '\0';
}

char* strchr(const char* str, char c) {
    while (*str) {
        if (*str == c) return (char*)str;
        str++;
    }
    return NULL;
}

void memcpy(void* dest, const void* src, size_t n) {
    uint8_t* d = dest;
    const uint8_t* s = src;
    while (n--) *d++ = *s++;
}

void memset(void* ptr, int value, size_t n) {
    uint8_t* p = ptr;
    while (n--) *p++ = value;
}

// ==================== TERMINAL FUNCTIONS ====================
static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | (uint16_t)color << 8;
}

void term_clear() {
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA_MEMORY[i] = vga_entry(' ', term_color);
    }
    term_row = 0;
    term_col = 0;
}

void term_scroll() {
    for (int i = 0; i < VGA_WIDTH * (VGA_HEIGHT - 1); i++) {
        VGA_MEMORY[i] = VGA_MEMORY[i + VGA_WIDTH];
    }
    for (int i = VGA_WIDTH * (VGA_HEIGHT - 1); i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA_MEMORY[i] = vga_entry(' ', term_color);
    }
    term_row = VGA_HEIGHT - 1;
}

void term_putchar(char c) {
    if (c == '\n') {
        term_col = 0;
        if (++term_row >= VGA_HEIGHT) term_scroll();
    } else if (c == '\b') {
        if (term_col > 0) {
            term_col--;
            VGA_MEMORY[term_row * VGA_WIDTH + term_col] = vga_entry(' ', term_color);
        }
    } else {
        VGA_MEMORY[term_row * VGA_WIDTH + term_col] = vga_entry(c, term_color);
        if (++term_col >= VGA_WIDTH) {
            term_col = 0;
            if (++term_row >= VGA_HEIGHT) term_scroll();
        }
    }
}

void term_write(const char* str) {
    while (*str) term_putchar(*str++);
}

void term_setcolor(uint8_t color) {
    term_color = color;
}

// ==================== FILE SYSTEM IMPLEMENTATION ====================
fs_node_t* fs_find_child(fs_node_t* parent, const char* name) {
    if (!parent || parent->type != FS_DIRECTORY) return NULL;
    
    for (int i = 0; i < parent->child_count; i++) {
        if (strcmp(parent->children[i]->name, name) == 0) {
            return parent->children[i];
        }
    }
    return NULL;
}

fs_node_t* fs_create_node(const char* name, fs_node_type type, fs_node_t* parent) {
    if (fs_node_count >= MAX_FILES) return NULL;
    
    fs_node_t* node = &fs_nodes[fs_node_count++];
    strcpy(node->name, name);
    node->type = type;
    node->size = 0;
    node->content = NULL;
    node->parent = parent;
    node->child_count = 0;
    node->permissions = 0x75;  // Fixed: Use smaller value that fits in uint8_t
    
    // Add to parent
    if (parent && parent->child_count < MAX_FILES) {
        parent->children[parent->child_count++] = node;
    }
    
    return node;
}

void fs_init() {
    // Initialize file system
    fs_node_count = 0;
    file_data_used = 0;
    
    // Create root directory
    fs_root = fs_create_node("/", FS_DIRECTORY, NULL);
    current_dir = fs_root;
    
    // Create standard directories
    fs_create_node("home", FS_DIRECTORY, fs_root);
    fs_create_node("bin", FS_DIRECTORY, fs_root);
    fs_create_node("etc", FS_DIRECTORY, fs_root);
    fs_create_node("tmp", FS_DIRECTORY, fs_root);
    fs_create_node("var", FS_DIRECTORY, fs_root);
    
    // Create some default files
    fs_node_t* etc = fs_find_child(fs_root, "etc");
    if (etc) {
        fs_node_t* motd = fs_create_node("motd", FS_FILE, etc);
        if (motd) {
            const char* motd_content = "Welcome to HybridOS!\nThe future of computing.\n";
            if (file_data_used + strlen(motd_content) + 1 < sizeof(file_data_pool)) {
                motd->content = &file_data_pool[file_data_used];
                strcpy(motd->content, motd_content);
                motd->size = strlen(motd_content);
                file_data_used += motd->size + 1;
            }
        }
        
        fs_node_t* version = fs_create_node("version", FS_FILE, etc);
        if (version) {
            const char* ver_content = "HybridOS v1.0\nKernel: 5.0-hybrid\n";
            if (file_data_used + strlen(ver_content) + 1 < sizeof(file_data_pool)) {
                version->content = &file_data_pool[file_data_used];
                strcpy(version->content, ver_content);
                version->size = strlen(ver_content);
                file_data_used += version->size + 1;
            }
        }
    }
    
    // Create user home directory
    fs_node_t* home = fs_find_child(fs_root, "home");
    if (home) {
        fs_node_t* user = fs_create_node("user", FS_DIRECTORY, home);
        if (user) {
            fs_node_t* readme = fs_create_node("readme.txt", FS_FILE, user);
            if (readme) {
                const char* readme_content = "Your files go here!\n";
                if (file_data_used + strlen(readme_content) + 1 < sizeof(file_data_pool)) {
                    readme->content = &file_data_pool[file_data_used];
                    strcpy(readme->content, readme_content);
                    readme->size = strlen(readme_content);
                    file_data_used += readme->size + 1;
                }
            }
        }
    }
}

fs_node_t* fs_resolve_path(const char* path) {
    if (!path || !*path) return current_dir;
    
    fs_node_t* node;
    char temp_path[MAX_PATH];
    strcpy(temp_path, path);
    
    // Absolute or relative path?
    if (path[0] == '/') {
        node = fs_root;
        char* p = temp_path + 1;
        char* token = p;
        
        while (*p) {
            if (*p == '/') {
                *p = '\0';
                if (*token) {
                    node = fs_find_child(node, token);
                    if (!node) return NULL;
                }
                token = p + 1;
            }
            p++;
        }
        if (*token) {
            node = fs_find_child(node, token);
        }
    } else {
        // Relative path
        node = current_dir;
        char* token = temp_path;
        char* p = temp_path;
        
        while (*p) {
            if (*p == '/') {
                *p = '\0';
                if (strcmp(token, "..") == 0) {
                    if (node->parent) node = node->parent;
                } else if (strcmp(token, ".") != 0 && *token) {
                    node = fs_find_child(node, token);
                    if (!node) return NULL;
                }
                token = p + 1;
            }
            p++;
        }
        if (*token) {
            if (strcmp(token, "..") == 0) {
                if (node->parent) node = node->parent;
            } else if (strcmp(token, ".") != 0) {
                node = fs_find_child(node, token);
            }
        }
    }
    
    return node;
}

void fs_get_path(fs_node_t* node, char* buffer) {
    if (!node || node == fs_root) {
        strcpy(buffer, "/");
        return;
    }
    
    // Build path recursively
    char temp[MAX_PATH];
    char* p = temp + MAX_PATH - 1;
    *p = '\0';
    
    while (node && node != fs_root) {
        size_t len = strlen(node->name);
        p -= len;
        memcpy(p, node->name, len);
        p--;
        *p = '/';
        node = node->parent;
    }
    
    strcpy(buffer, p);
}

// ==================== FILE SYSTEM COMMANDS ====================
void cmd_ls(const char* path) {
    fs_node_t* dir = path && *path ? fs_resolve_path(path) : current_dir;
    
    if (!dir) {
        term_setcolor(0x0C);
        term_write("ls: cannot access '");
        term_write(path);
        term_write("': No such file or directory\n");
        term_setcolor(0x07);
        return;
    }
    
    if (dir->type != FS_DIRECTORY) {
        // List single file
        term_setcolor(0x0F);
        term_write(dir->name);
        term_write("\n");
        term_setcolor(0x07);
        return;
    }
    
    // List directory contents
    for (int i = 0; i < dir->child_count; i++) {
        fs_node_t* child = dir->children[i];
        
        if (child->type == FS_DIRECTORY) {
            term_setcolor(0x09);  // Blue for directories
            term_write(child->name);
            term_write("/");
        } else {
            term_setcolor(0x0F);  // White for files
            term_write(child->name);
        }
        
        // Show size for files
        if (child->type == FS_FILE) {
            term_setcolor(0x08);
            term_write("  (");
            // Simple number to string
            char size_str[16];
            int idx = 15;
            size_str[idx--] = '\0';
            size_t size = child->size;
            if (size == 0) {
                size_str[idx--] = '0';
            } else {
                while (size > 0 && idx >= 0) {
                    size_str[idx--] = '0' + (size % 10);
                    size /= 10;
                }
            }
            term_write(&size_str[idx + 1]);
            term_write(" bytes)");
        }
        
        term_write("\n");
    }
    term_setcolor(0x07);
}

void cmd_cd(const char* path) {
    if (!path || !*path) {
        current_dir = fs_root;
        strcpy(current_path, "/");
        return;
    }
    
    fs_node_t* new_dir = fs_resolve_path(path);
    if (!new_dir) {
        term_setcolor(0x0C);
        term_write("cd: ");
        term_write(path);
        term_write(": No such file or directory\n");
        term_setcolor(0x07);
        return;
    }
    
    if (new_dir->type != FS_DIRECTORY) {
        term_setcolor(0x0C);
        term_write("cd: ");
        term_write(path);
        term_write(": Not a directory\n");
        term_setcolor(0x07);
        return;
    }
    
    current_dir = new_dir;
    fs_get_path(current_dir, current_path);
}

void cmd_pwd() {
    term_write(current_path);
    term_write("\n");
}

void cmd_mkdir(const char* name) {
    if (!name || !*name) {
        term_setcolor(0x0C);
        term_write("mkdir: missing operand\n");
        term_setcolor(0x07);
        return;
    }
    
    // Check if already exists
    if (fs_find_child(current_dir, name)) {
        term_setcolor(0x0C);
        term_write("mkdir: cannot create directory '");
        term_write(name);
        term_write("': File exists\n");
        term_setcolor(0x07);
        return;
    }
    
    fs_node_t* new_dir = fs_create_node(name, FS_DIRECTORY, current_dir);
    if (!new_dir) {
        term_setcolor(0x0C);
        term_write("mkdir: cannot create directory: Out of space\n");
        term_setcolor(0x07);
    }
}

void cmd_touch(const char* name) {
    if (!name || !*name) {
        term_setcolor(0x0C);
        term_write("touch: missing file operand\n");
        term_setcolor(0x07);
        return;
    }
    
    // Check if already exists
    fs_node_t* existing = fs_find_child(current_dir, name);
    if (existing) {
        return; // Just update timestamp (not implemented)
    }
    
    fs_node_t* new_file = fs_create_node(name, FS_FILE, current_dir);
    if (!new_file) {
        term_setcolor(0x0C);
        term_write("touch: cannot create file: Out of space\n");
        term_setcolor(0x07);
    }
}

void cmd_cat(const char* filename) {
    if (!filename || !*filename) {
        term_setcolor(0x0C);
        term_write("cat: missing file operand\n");
        term_setcolor(0x07);
        return;
    }
    
    fs_node_t* file = fs_resolve_path(filename);
    if (!file) {
        term_setcolor(0x0C);
        term_write("cat: ");
        term_write(filename);
        term_write(": No such file or directory\n");
        term_setcolor(0x07);
        return;
    }
    
    if (file->type == FS_DIRECTORY) {
        term_setcolor(0x0C);
        term_write("cat: ");
        term_write(filename);
        term_write(": Is a directory\n");
        term_setcolor(0x07);
        return;
    }
    
    if (file->content) {
        term_write(file->content);
        if (file->size > 0 && file->content[file->size - 1] != '\n') {
            term_write("\n");
        }
    }
}

void cmd_echo(const char* args) {
    if (!args || !*args) {
        term_write("\n");
        return;
    }
    
    // Check for redirection
    char* redirect = strchr(args, '>');
    if (redirect) {
        *redirect = '\0';
        redirect++;
        while (*redirect == ' ' || *redirect == '>') redirect++;
        
        if (*redirect) {
            // Write to file
            fs_node_t* file = fs_find_child(current_dir, redirect);
            if (!file) {
                file = fs_create_node(redirect, FS_FILE, current_dir);
            }
            
            if (file && file->type == FS_FILE) {
                // Allocate content if needed
                size_t len = strlen(args);
                while (len > 0 && args[len-1] == ' ') len--;  // Trim trailing spaces
                
                if (file_data_used + len + 2 < sizeof(file_data_pool)) {
                    if (!file->content) {
                        file->content = &file_data_pool[file_data_used];
                    }
                    
                    // Copy content
                    memcpy(file->content, args, len);
                    file->content[len] = '\n';
                    file->content[len + 1] = '\0';
                    file->size = len + 1;
                    file_data_used = (file->content - file_data_pool) + file->size + 1;
                }
            } else {
                term_setcolor(0x0C);
                term_write("echo: cannot write to '");
                term_write(redirect);
                term_write("'\n");
                term_setcolor(0x07);
            }
        }
    } else {
        term_write(args);
        term_write("\n");
    }
}

void cmd_rm(const char* filename) {
    if (!filename || !*filename) {
        term_setcolor(0x0C);
        term_write("rm: missing operand\n");
        term_setcolor(0x07);
        return;
    }
    
    // Find file in current directory
    for (int i = 0; i < current_dir->child_count; i++) {
        if (strcmp(current_dir->children[i]->name, filename) == 0) {
            fs_node_t* node = current_dir->children[i];
            
            if (node->type == FS_DIRECTORY && node->child_count > 0) {
                term_setcolor(0x0C);
                term_write("rm: cannot remove '");
                term_write(filename);
                term_write("': Directory not empty\n");
                term_setcolor(0x07);
                return;
            }
            
            // Remove from parent's children list
            for (int j = i; j < current_dir->child_count - 1; j++) {
                current_dir->children[j] = current_dir->children[j + 1];
            }
            current_dir->child_count--;
            
            return;
        }
    }
    
    term_setcolor(0x0C);
    term_write("rm: cannot remove '");
    term_write(filename);
    term_write("': No such file or directory\n");
    term_setcolor(0x07);
}

// ==================== KEYBOARD INPUT ====================
char read_key() {
    static const char scancode_ascii[] = {
        0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
        '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
        0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
        0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
        '*', 0, ' '
    };
    
    while (!(inb(0x64) & 1));
    uint8_t scancode = inb(0x60);
    
    if (scancode & 0x80) return 0;
    if (scancode < sizeof(scancode_ascii)) {
        return scancode_ascii[scancode];
    }
    return 0;
}

void get_input(char* buffer, int max_len) {
    int pos = 0;
    char c;
    
    while (pos < max_len - 1) {
        c = read_key();
        
        if (c == '\n') {
            buffer[pos] = '\0';
            term_putchar('\n');
            break;
        } else if (c == '\b' && pos > 0) {
            pos--;
            term_putchar('\b');
        } else if (c && c != '\b') {
            buffer[pos++] = c;
            term_putchar(c);
        }
    }
}

// ==================== COMMAND PROCESSING ====================
void cmd_help() {
    term_setcolor(0x0F);
    term_write("\nHybridOS File System Commands:\n");
    term_write("==============================\n");
    
    term_setcolor(0x0A);
    term_write("  ls [path]      "); term_setcolor(0x07); term_write("- List directory contents\n");
    term_setcolor(0x0A);
    term_write("  cd <path>      "); term_setcolor(0x07); term_write("- Change directory\n");
    term_setcolor(0x0A);
    term_write("  pwd            "); term_setcolor(0x07); term_write("- Print working directory\n");
    term_setcolor(0x0A);
    term_write("  mkdir <name>   "); term_setcolor(0x07); term_write("- Create directory\n");
    term_setcolor(0x0A);
    term_write("  touch <name>   "); term_setcolor(0x07); term_write("- Create empty file\n");
    term_setcolor(0x0A);
    term_write("  cat <file>     "); term_setcolor(0x07); term_write("- Display file contents\n");
    term_setcolor(0x0A);
    term_write("  echo <text>    "); term_setcolor(0x07); term_write("- Display text\n");
    term_setcolor(0x0A);
    term_write("  echo text > f  "); term_setcolor(0x07); term_write("- Write text to file\n");
    term_setcolor(0x0A);
    term_write("  rm <file>      "); term_setcolor(0x07); term_write("- Remove file or empty directory\n");
    term_setcolor(0x0A);
    term_write("  clear          "); term_setcolor(0x07); term_write("- Clear screen\n");
    term_setcolor(0x0A);
    term_write("  help           "); term_setcolor(0x07); term_write("- Show this help\n");
    term_setcolor(0x0A);
    term_write("  tree           "); term_setcolor(0x07); term_write("- Show directory tree\n");
    term_setcolor(0x0A);
    term_write("  about          "); term_setcolor(0x07); term_write("- About HybridOS\n");
}

// Tree display helper
void display_tree_node(fs_node_t* node, int depth, bool last[]) {
    // Display current node
    for (int i = 0; i < depth; i++) {
        if (i == depth - 1) {
            term_write(last[i] ? "`-- " : "|-- ");
        } else {
            term_write(last[i] ? "    " : "|   ");
        }
    }
    
    if (node->type == FS_DIRECTORY) {
        term_setcolor(0x09);
        term_write(node->name);
        term_write("/\n");
    } else {
        term_setcolor(0x0F);
        term_write(node->name);
        term_write("\n");
    }
    term_setcolor(0x07);
    
    // Display children
    if (node->type == FS_DIRECTORY) {
        for (int i = 0; i < node->child_count; i++) {
            last[depth] = (i == node->child_count - 1);
            display_tree_node(node->children[i], depth + 1, last);
        }
    }
}

void cmd_tree() {
    term_setcolor(0x0E);
    term_write(".\n");
    term_setcolor(0x07);
    
    bool last[32] = {false};
    for (int i = 0; i < current_dir->child_count; i++) {
        last[0] = (i == current_dir->child_count - 1);
        display_tree_node(current_dir->children[i], 1, last);
    }
}

void process_command(char* cmd) {
    // Parse command and arguments
    char command[64];
    char args[192];
    int i = 0, j = 0;
    
    // Extract command
    while (cmd[i] && cmd[i] != ' ' && j < 63) {
        command[j++] = cmd[i++];
    }
    command[j] = '\0';
    
    // Skip spaces
    while (cmd[i] == ' ') i++;
    
    // Get arguments
    j = 0;
    while (cmd[i] && j < 191) {
        args[j++] = cmd[i++];
    }
    args[j] = '\0';
    
    // Execute command
    if (strcmp(command, "help") == 0) {
        cmd_help();
    } else if (strcmp(command, "clear") == 0) {
        term_clear();
    } else if (strcmp(command, "ls") == 0) {
        cmd_ls(args[0] ? args : NULL);
    } else if (strcmp(command, "cd") == 0) {
        cmd_cd(args);
    } else if (strcmp(command, "pwd") == 0) {
        cmd_pwd();
    } else if (strcmp(command, "mkdir") == 0) {
        cmd_mkdir(args);
    } else if (strcmp(command, "touch") == 0) {
        cmd_touch(args);
    } else if (strcmp(command, "cat") == 0) {
        cmd_cat(args);
    } else if (strcmp(command, "echo") == 0) {
        cmd_echo(args);
    } else if (strcmp(command, "rm") == 0) {
        cmd_rm(args);
    } else if (strcmp(command, "tree") == 0) {
        cmd_tree();
    } else if (strcmp(command, "about") == 0) {
        term_setcolor(0x0E);
        term_write("\n=== HybridOS v1.0 ===\n");
        term_setcolor(0x0B);
        term_write("Virtual File System Active\n");
        term_setcolor(0x07);
        term_write("- Full directory structure\n");
        term_write("- File creation and editing\n");
        term_write("- Windows + Linux unified\n");
    } else if (command[0] != '\0') {
        term_setcolor(0x0C);
        term_write("Command not found: ");
        term_write(command);
        term_write("\n");
        term_setcolor(0x07);
    }
}

// ==================== MAIN KERNEL ====================
void kernel_main(void) {
    // Initialize
    term_clear();
    
    // Initialize file system
    fs_init();
    
    // Boot message
    term_setcolor(0x0B);
    term_write("================================================================================\n");
    term_setcolor(0x0F);
    term_write("                 HybridOS v1.0 - Virtual File System Active                     \n");
    term_setcolor(0x0B);
    term_write("================================================================================\n\n");
    
    term_setcolor(0x0E);
    term_write("File system initialized with ");
    term_write("/home, /bin, /etc structure\n");
    term_write("Type 'help' for available commands\n\n");
    
    // Show initial directory listing
    term_setcolor(0x0A);
    term_write("Contents of /:\n");
    term_setcolor(0x07);
    cmd_ls(NULL);
    term_write("\n");
    
    // Main loop
    while (1) {
        // Show prompt with current path
        term_setcolor(0x0A);
        term_write("[");
        term_setcolor(0x0E);
        term_write(current_path);
        term_setcolor(0x0A);
        term_write("]");
        term_setcolor(0x0B);
        term_write(" HybridOS> ");
        term_setcolor(0x07);
        
        get_input(input_buffer, 256);
        process_command(input_buffer);
    }
}