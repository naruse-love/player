use lofty::config::WriteOptions;
use lofty::prelude::*;

/// 将歌词写入音频文件的标签中
/// 返回成功的消息，失败时返回错误描述
pub fn set_lyric_to_path(path: String, lyric: String) -> Result<String, String> {
    let mut tagged_file =
        lofty::read_from_path(&path).map_err(|e| format!("无法读取音频文件: {e}"))?;

    // 获取或创建标签
    let tag = tagged_file
        .primary_tag_mut()
        .or_else(|| tagged_file.first_tag_mut())
        .ok_or_else(|| "该文件格式不支持标签".to_string())?;

    // 使用 insert_text 简化歌词写入
    tag.insert_text(ItemKey::Lyrics, lyric);

    // 写回文件
    tagged_file
        .save(&WriteOptions::new())
        .map_err(|e| format!("写入歌词失败: {e}"))?;

    Ok("歌词已保存到文件".to_string())
}
