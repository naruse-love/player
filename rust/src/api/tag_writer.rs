use std::fs::File;
use std::io::BufWriter;

use lofty::prelude::*;

/// 将歌词写入音频文件的标签中
pub fn set_lyric_to_path(path: String, lyric: String) -> Result<String, String> {
    let mut tagged_file =
        lofty::read_from_path(&path).map_err(|e| format!("无法读取音频文件: {e}"))?;

    let tag = tagged_file
        .primary_tag_mut()
        .or_else(|| tagged_file.first_tag_mut())
        .ok_or_else(|| "该文件格式不支持标签".to_string())?;

    tag.insert_text(ItemKey::Lyrics, lyric);

    // 通过 AudioFile::write_to 写回
    let file = File::create(&path).map_err(|e| format!("无法创建文件: {e}"))?;
    let mut writer = BufWriter::new(file);
    tagged_file
        .write_to(&mut writer)
        .map_err(|e| format!("写入歌词失败: {e}"))?;

    Ok("歌词已保存到文件".to_string())
}
