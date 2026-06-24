use lofty::config::WriteOptions;
use lofty::prelude::*;

/// 将歌词写入音频文件的标签中
pub fn set_lyric_to_path(path: String, lyric: String) -> anyhow::Result<String> {
    let mut tagged_file =
        lofty::read_from_path(&path).map_err(|e| anyhow::anyhow!("无法读取音频文件: {e}"))?;

    let tag = tagged_file
        .primary_tag_mut()
        .or_else(|| tagged_file.first_tag_mut())
        .ok_or_else(|| anyhow::anyhow!("该文件格式不支持标签"))?;

    tag.insert_text(ItemKey::Lyrics, lyric);

    // 通过 AudioFile::save_to_path 写回
    tagged_file
        .save_to_path(&path, WriteOptions::default())
        .map_err(|e| anyhow::anyhow!("写入歌词失败: {e}"))?;

    Ok("歌词已保存到文件".to_string())
}
