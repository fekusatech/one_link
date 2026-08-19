
-- Table structure for table `app_versions`
CREATE TABLE `app_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `version_number` varchar(20) NOT NULL COMMENT 'e.g. 1.0.1',
  `build_number` int(11) NOT NULL COMMENT 'Incrementing integer, e.g. 1, 2, 3',
  `download_url` text NOT NULL COMMENT 'Direct link to .apk file',
  `force_update` tinyint(1) DEFAULT 0 COMMENT '1 = Mandatory update, 0 = Optional',
  `release_notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example data (Insert your first version)
INSERT INTO `app_versions` (`version_number`, `build_number`, `download_url`, `force_update`, `release_notes`) VALUES
('1.0.0', 1, 'https://your-domain.com/downloads/one_link_v1.apk', 0, 'Initial Release');

/*
API UPDATE GUIDE:

Buatlah endpoint (misal: GET /api/check_version) yang mengambil:
SELECT * FROM app_versions ORDER BY build_number DESC LIMIT 1;

Dan return JSON format seperti ini:
{
    "success": true,
    "data": {
        "version": "1.0.1",
        "build_number": 2,
        "url": "https://your-domain.com/downloads/one_link_v1.apk",
        "force_update": true,
        "release_notes": "Perbaikan bug login dan update layout GPS"
    }
}
*/
