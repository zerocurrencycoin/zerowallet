# TODO

## UI / UX (macOS DMG testing 2026-02)

- ~~**Save transactions (Export transactions):** File dialog does not allow selecting directory~~ Fixed: default to Documents.
- ~~**Backup wallet.zero:** File dialog does not allow selecting directory~~ Fixed: default to Documents.
- ~~**Help / About dialogs:** Opened windows lack iconize (minimize) or quit (close) in title bar~~ Fixed: setWindowFlags(Qt::Window) for About and Settings.
- ~~**Addresses with 0 balance not shown under Balances**~~ Fixed: include zero-balance in addressBalances and balancesOverview.
- ~~**Save problem in other menu dialogs**~~ Fixed: Import Address Book, Choose data directory now use proper default paths.

### File dialog default directory (refactor candidate)

Repeated pattern: `QStandardPaths::writableLocation(QStandardPaths::HomeLocation)` used at 5 call sites for user-facing save/open dialogs. Each site is 2–3 lines; repetition is minor but centralizing would simplify future changes (e.g., switch default to Documents).

**References:**

| File | Line | Usage | API |
|------|------|-------|-----|
| `src/mainwindow.cpp` | 1168 | Export transactions | `getSaveFileUrl` with default filename |
| `src/mainwindow.cpp` | 1206 | Backup wallet.zero | `getSaveFileUrl` with default filename |
| `src/mainwindow.cpp` | 1251 | Export private keys | `getSaveFileName` with default filename |
| `src/addressbook.cpp` | 156 | Import Address Book | `getOpenFileUrl` (dir only) |
| `src/connection.cpp` | 164 | Choose data directory | `getExistingDirectory` |

**Proposed helper (optional):**

```cpp
// e.g. in a util or precompiled header
static inline QString defaultFileDialogDir() {
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
}
```

Replace each `QString dir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);` with `QString dir = defaultFileDialogDir();`. Low priority; current inline code is acceptable.

---

# Security Vulnerability Report & Recommendations

## Critical Security Issues Found

### HIGH SEVERITY

#### 1. Memory Leak in Password Generation
- **File:** `src/connection.cpp:116-123`
- **Issue:** Function `randomPassword()` allocates memory with `new char[]` but never frees it
- **Code:**
  ```cpp
  char* s = new char[passwordLength + 1];
  // ... code
  return QString::fromStdString(s); // Memory leaked
  ```
- **Impact:** Memory exhaustion over time, potential DoS
- **Fix:** Add `delete[] s;` after converting to QString, or use smart pointers/RAII

#### 2. Buffer Index Vulnerability
- **File:** `src/connection.cpp:119`
- **Issue:** Off-by-one error in array access
- **Code:**
  ```cpp
  s[i] = alphanum[randombytes_uniform(sizeof(alphanum))];
  ```
- **Impact:** `sizeof(alphanum)` includes null terminator, `randombytes_uniform` could return index equal to size
- **Fix:** Use `sizeof(alphanum) - 1` to exclude null terminator

#### 3. Insecure Network Binding
- **File:** `src/websockets.cpp:28`
- **Issue:** WebSocket server listens on all IPv4 interfaces
- **Code:**
  ```cpp
  if (m_pWebSocketServer->listen(QHostAddress::AnyIPv4, port)) {
  ```
- **Impact:** Remote attackers can connect to the wallet service
- **Fix:** Bind only to localhost (`QHostAddress::LocalHost`)

### MEDIUM SEVERITY

#### 4. Weak Password Generation
- **File:** `src/connection.cpp:115`
- **Issue:** Auto-generated passwords only use 10 characters
- **Code:**
  ```cpp
  const int passwordLength = 10;
  ```
- **Impact:** Insufficient entropy for brute force protection
- **Fix:** Increase password length to at least 32 characters

#### 5. Credentials Stored in Plain Text
- **File:** `src/settings.cpp:242-243`
- **Issue:** RPC username and password stored unencrypted
- **Impact:** Credential theft if system is compromised
- **Fix:** Encrypt credentials before storage or use OS credential store

#### 6. Insecure HTTP Connections
- **File:** `src/rpc.cpp:1538`
- **Issue:** Using HTTP instead of HTTPS for external API calls
- **Impact:** Man-in-the-middle attacks, data interception
- **Fix:** Change to HTTPS URLs

## Security Recommendations

### Immediate Actions Required
1. **Fix memory leak** in password generation function
2. **Fix buffer overflow** in random character selection
3. **Change WebSocket binding** to localhost only
4. **Increase password length** to 32+ characters
5. **Switch to HTTPS** for all external communications

### Security Improvements
1. **Implement secure memory management** for all sensitive data
2. **Add input validation and sanitization** for all user inputs
3. **Use HTTPS exclusively** for external network communications
4. **Implement certificate pinning** for critical external services
5. **Add rate limiting** to prevent brute force attacks
6. **Implement proper access controls** for WebSocket connections
7. **Add security event logging and monitoring**
8. **Use secure random number generation** for all cryptographic operations
9. **Implement proper session management** for mobile app connections
10. **Add integrity checks** for configuration files

### Code Quality Improvements
1. Use RAII and smart pointers for automatic memory management
2. Implement comprehensive input validation
3. Add bounds checking for all array/buffer operations
4. Use const-correctness throughout the codebase
5. Add unit tests for security-critical functions

### Network Security
1. Implement TLS/SSL for all network communications
2. Add connection authentication and authorization
3. Implement network timeouts and rate limiting
4. Use secure protocols (WSS instead of WS, HTTPS instead of HTTP)
5. Add network traffic encryption for sensitive data

### Cryptographic Security
1. Use well-tested cryptographic libraries (libsodium is good choice)
2. Implement proper key derivation and storage
3. Add secure random number generation validation
4. Implement proper nonce handling and replay protection
5. Add cryptographic integrity checks

## Testing Requirements
1. **Memory leak testing** with valgrind or similar tools
2. **Security penetration testing** for network services
3. **Input fuzzing** for all user input handlers
4. **Cryptographic testing** for key generation and encryption
5. **Performance testing** under high load conditions

## Monitoring & Logging
1. Add security event logging
2. Implement intrusion detection
3. Add performance monitoring
4. Implement audit trails for sensitive operations
5. Add alerting for security events

---
**Note:** This analysis was performed on the main application source files. A complete security audit should also include analysis of the build system, dependencies, and deployment configurations.