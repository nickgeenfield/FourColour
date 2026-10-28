// rm-comics AppLoad backend. Speaks the AppLoad SEQPACKET protocol on argv[1].
// Messages in : 1 = list dir, 2 = open comic, 3 = save "page\tpath", 4 = delete comic file
// Messages out: 101 = listing JSON, 102 = opened JSON, 103 = deleted JSON, 198 = delete error, 199 = open error
use serde_json::json;
use std::collections::HashMap;
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

fn home() -> String { std::env::var("RMCOMICS_HOME").unwrap_or_else(|_| "/home/root".into()) }
fn cache() -> String { format!("{}/.cache/rm-comics", home()) }
fn state() -> String { format!("{}/.local/share/rm-comics/progress.json", home()) }
fn comics_root() -> String { std::env::var("RMCOMICS_COMICS").unwrap_or_else(|_| format!("{}/comics", home())) }
const MAX: usize = 10485760;

fn send(fd: i32, t: u32, s: &str) {
    let b = s.as_bytes();
    let hdr: [u32; 2] = [t, b.len() as u32];
    unsafe {
        libc::send(fd, hdr.as_ptr() as *const _, 8, 0);
        if !b.is_empty() { libc::send(fd, b.as_ptr() as *const _, b.len(), 0); }
    }
}

fn is_img(n: &str) -> bool {
    let l = n.to_lowercase();
    if l.contains("__macosx") || l.rsplit('/').next().map_or(false, |f| f.starts_with('.')) { return false; }
    [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"].iter().any(|e| l.ends_with(e))
}

// natural sort key: split digits and text
fn nat_key(s: &str) -> Vec<(u8, u64, String)> {
    let mut out = vec![]; let mut cur = String::new(); let mut dig = false;
    for c in s.to_lowercase().chars() {
        let d = c.is_ascii_digit();
        if !cur.is_empty() && d != dig { out.push(seg(&cur, dig)); cur.clear(); }
        dig = d; cur.push(c);
    }
    if !cur.is_empty() { out.push(seg(&cur, dig)); }
    out
}
fn seg(s: &str, d: bool) -> (u8, u64, String) {
    if d { (0, s.parse().unwrap_or(u64::MAX), s.to_string()) } else { (1, 0, s.to_string()) }
}

fn load_state() -> HashMap<String, u64> {
    fs::read_to_string(state()).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default()
}
fn save_state(m: &HashMap<String, u64>) {
    if let Some(p) = Path::new(&state()).parent() { let _ = fs::create_dir_all(p); }
    let tmp = format!("{}.tmp", state());
    if fs::write(&tmp, serde_json::to_string(m).unwrap()).is_ok() { let _ = fs::rename(tmp, state()); }
}

fn list(dir: &str) -> String {
    let mut v: Vec<(bool, String)> = vec![];
    if let Ok(rd) = fs::read_dir(dir) {
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().to_string();
            if n.starts_with('.') { continue; }
            let isdir = e.path().is_dir();
            let l = n.to_lowercase();
            if isdir || l.ends_with(".cbz") || l.ends_with(".zip") || l.ends_with(".cbr") || l.ends_with(".rar") { v.push((isdir, n)); }
        }
    }
    v.sort_by(|a, b| b.0.cmp(&a.0).then(nat_key(&a.1).cmp(&nat_key(&b.1))));
    let st = load_state();
    let ents: Vec<_> = v.iter().map(|(d, n)| {
        let full = format!("{}/{}", dir.trim_end_matches('/'), n);
        json!({"name": n, "dir": d, "path": full, "page": st.get(&full).copied()})
    }).collect();
    json!({"dir": dir, "entries": ents}).to_string()
}

fn magic(p: &str) -> [u8; 4] {
    let mut b = [0u8; 4];
    if let Ok(mut f) = fs::File::open(p) { let _ = f.read(&mut b); }
    b
}

fn extract(src: &str, out: &Path) -> Result<Vec<String>, String> {
    let m = magic(src);
    let mut names: Vec<(String, Vec<u8>)> = vec![];
    if &m == b"PK\x03\x04" {
        let f = fs::File::open(src).map_err(|e| e.to_string())?;
        let mut z = zip::ZipArchive::new(f).map_err(|e| format!("Not a readable zip: {e}"))?;
        for i in 0..z.len() {
            let mut e = z.by_index(i).map_err(|e| e.to_string())?;
            if e.is_dir() || !is_img(e.name()) { continue; }
            let mut buf = vec![]; e.read_to_end(&mut buf).map_err(|e| e.to_string())?;
            names.push((e.name().to_string(), buf));
        }
    } else if &m == b"Rar!" {
        let mut a = unrar::Archive::new(src).open_for_processing().map_err(|e| format!("Cannot open RAR: {e}"))?;
        while let Some(h) = a.read_header().map_err(|e| format!("RAR error: {e}"))? {
            let name = h.entry().filename.to_string_lossy().to_string();
            a = if h.entry().is_file() && is_img(&name) {
                let (data, next) = h.read().map_err(|e| format!("RAR read error: {e}"))?;
                names.push((name, data)); next
            } else { h.skip().map_err(|e| e.to_string())? };
        }
    } else {
        return Err("Unknown archive type (not zip or rar)".into());
    }
    if names.is_empty() { return Err("No images found in this comic".into()); }
    names.sort_by(|a, b| nat_key(&a.0).cmp(&nat_key(&b.0)));
    let mut pages = vec![];
    for (i, (n, d)) in names.iter().enumerate() {
        let ext = n.rsplit('.').next().unwrap_or("jpg").to_lowercase();
        let p = out.join(format!("{:04}.{}", i, ext));
        fs::File::create(&p).and_then(|mut f| f.write_all(d)).map_err(|e| e.to_string())?;
        pages.push(p.to_string_lossy().to_string());
    }
    Ok(pages)
}

fn cache_key(src: &str, len: u64) -> String {
    format!("{:x}", src.bytes().fold(len ^ 0xcbf29ce484222325, |h, b| (h ^ b as u64).wrapping_mul(0x100000001b3)))
}

fn is_comic(n: &str) -> bool {
    let l = n.to_lowercase();
    [".cbz", ".zip", ".cbr", ".rar"].iter().any(|e| l.ends_with(e))
}

// Delete ONE comic file inside the comics folder. Folders are never deleted.
fn delete(src: &str) -> Result<String, String> {
    let p = Path::new(src);
    if !p.is_absolute() { return Err("Not an absolute path".into()); }
    if src.contains('\0') || src[1..].split('/').any(|seg| seg.is_empty() || seg == "." || seg == "..")
        || p.components().any(|c| !matches!(c, std::path::Component::RootDir | std::path::Component::Normal(_))) {
        return Err("Path contains '..' or '.'".into());
    }
    let root = fs::canonicalize(comics_root()).map_err(|e| format!("Comics folder missing: {e}"))?;
    let name = p.file_name().ok_or("No file name")?.to_string_lossy().to_string();
    if name.starts_with('.') || !is_comic(&name) { return Err("Only .cbz/.cbr/.zip/.rar comics can be deleted".into()); }
    let parent = fs::canonicalize(p.parent().ok_or("No parent folder")?).map_err(|e| e.to_string())?;
    if !parent.starts_with(&root) { return Err("Outside the comics folder".into()); }
    let md = fs::symlink_metadata(p).map_err(|e| e.to_string())?;
    if md.file_type().is_symlink() {
        // A link is only removed (never its target), and only if it points inside the comics folder.
        let t = fs::canonicalize(p).map_err(|_| "Broken link".to_string())?;
        if !t.starts_with(&root) { return Err("Link points outside the comics folder".into()); }
        if !t.is_file() { return Err("Not a comic file".into()); }
    } else if !md.is_file() {
        return Err("Folders cannot be deleted from the app".into());
    }
    let len = fs::metadata(p).map(|m| m.len()).unwrap_or(md.len());
    fs::remove_file(p).map_err(|e| format!("Could not delete: {e}"))?;
    let _ = fs::remove_dir_all(PathBuf::from(cache()).join(cache_key(src, len)));
    let mut st = load_state();
    if st.remove(src).is_some() { save_state(&st); }
    Ok(json!({"deleted": src, "dir": p.parent().unwrap().to_string_lossy()}).to_string())
}

fn open(src: &str) -> Result<String, String> {
    let md = fs::metadata(src).map_err(|e| e.to_string())?;
    let key = cache_key(src, md.len());
    let base = PathBuf::from(cache());
    let out = base.join(&key);
    let done = out.join(".done");
    let pages: Vec<String> = if done.exists() {
        let mut v: Vec<String> = fs::read_dir(&out).map_err(|e| e.to_string())?.flatten()
            .map(|e| e.path().to_string_lossy().to_string()).filter(|p| !p.ends_with(".done")).collect();
        v.sort(); v
    } else {
        // keep only one comic cached to protect disk space
        let _ = fs::remove_dir_all(&base);
        fs::create_dir_all(&out).map_err(|e| e.to_string())?;
        let p = extract(src, &out).map_err(|e| { let _ = fs::remove_dir_all(&out); e })?;
        let _ = fs::write(&done, b"1");
        p
    };
    let page = load_state().get(src).copied().unwrap_or(0);
    Ok(json!({"path": src, "pages": pages, "page": page}).to_string())
}

fn main() {
    let sock = std::env::args().nth(1).unwrap_or_default();
    if sock == "--selftest" { println!("ok"); return; }
    let fd = unsafe { libc::socket(libc::AF_UNIX, libc::SOCK_SEQPACKET, 0) };
    let mut addr: libc::sockaddr_un = unsafe { std::mem::zeroed() };
    addr.sun_family = libc::AF_UNIX as u16;
    for (i, b) in sock.bytes().take(107).enumerate() { addr.sun_path[i] = b as libc::c_char; }
    if unsafe { libc::connect(fd, &addr as *const _ as *const libc::sockaddr, std::mem::size_of::<libc::sockaddr_un>() as u32) } != 0 { std::process::exit(1); }
    let mut buf = vec![0u8; MAX];
    loop {
        let mut hdr = [0u32; 2];
        if unsafe { libc::recv(fd, hdr.as_mut_ptr() as *mut _, 8, 0) } < 1 { break; }
        let (t, len) = (hdr[0], hdr[1] as usize);
        if len > MAX { break; }
        let s = if len > 0 {
            let r = unsafe { libc::recv(fd, buf.as_mut_ptr() as *mut _, len, 0) };
            if r < 1 { break; }
            String::from_utf8_lossy(&buf[..r as usize]).to_string()
        } else { String::new() };
        match t {
            0xFFFFFFFF => break,
            1 => send(fd, 101, &list(&s)),
            2 => match open(&s) { Ok(j) => send(fd, 102, &j), Err(e) => send(fd, 199, &e) },
            3 => if let Some((pg, path)) = s.split_once('\t') {
                let mut st = load_state();
                st.insert(path.to_string(), pg.parse().unwrap_or(0));
                save_state(&st);
            },
            4 => match delete(&s) { Ok(j) => send(fd, 103, &j), Err(e) => send(fd, 198, &e) },
            _ => {}
        }
    }
}
