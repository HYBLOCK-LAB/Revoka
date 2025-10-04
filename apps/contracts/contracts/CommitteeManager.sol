// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * 요구사항(위원회 부분) 반영:
 * - 위원회 멤버 추가/삭제, 임계치 설정(관리자 전용)
 * - submitShard(): 샤드 CID 이벤트 + 카운트 저장, 임계치 도달 시 ExecutionApproved 이벤트
 * - 코드 존재 여부는 ILicenseCore(codeCore).codeExists(codeId)로 확인
 * - 필요 시 isCodeActive(codeId)로 활성 상태까지 체크하도록 정책 변경 가능
 *   (예: 일시정지된 코드에 대한 샤드 제출 제한)
 */

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILicenseManager} from "./interfaces/ILicenseManager.sol";

contract CommitteeManager is AccessControl {
    /* ========= 전역 변수 ========= */

    bytes32 public constant COMMITTEE_ROLE = keccak256("COMMITTEE_ROLE");

    /// @notice 코드/라이선스 코어 컨트랙트 (읽기 의존)
    ILicenseManager public immutable licenseManager;

    constructor(address licenseManager_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        licenseManager = ILicenseManager(licenseManager_);
    }

    /* ========= 상태 ========= */

    // runKey = keccak256(abi.encodePacked(codeId))
    mapping(bytes32 => uint256) public shardCountForRun;
    uint256 public committeeThreshold = 2;

    /* ========= 이벤트 ========= */

    event ShardSubmitted(
        uint256 indexed codeId,
        bytes32 indexed runNonce,
        address indexed committee,
        string shardCid,
        uint256 countAfter
    );

    event ExecutionApproved(
        uint256 indexed codeId,
        bytes32 indexed runNonce,
        uint256 threshold,
        uint256 count
    );

    /* ========= 관리자 오퍼레이션 ========= */

    /// @notice 위원회 임계치 설정(관리자)
    function setCommitteeThreshold(
        uint256 newThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newThreshold > 0, "threshold=0");
        committeeThreshold = newThreshold;
    }

    /// @notice 위원회 멤버 추가(관리자)
    function addCommittee(address who) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(COMMITTEE_ROLE, who);
    }

    /// @notice 위원회 멤버 제거(관리자)
    function removeCommittee(
        address who
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(COMMITTEE_ROLE, who);
    }

    /* ========= 샤드 제출 ========= */

    /// @notice 위원회가 샤드 CID(IPFS)를 제출. 온체인에는 카운트만 저장, CID는 이벤트로 공개
    function submitShard(
        uint256 codeId,
        bytes32 runNonce,
        string calldata shardCid
    ) external onlyRole(COMMITTEE_ROLE) {
        require(licenseManager.checkCodeExists(codeId), "code !exist");
        // 정책상 활성 코드만 허용하려면 아래처럼 변경 가능:
        // require(codeCore.isCodeActive(codeId), "code paused");

        bytes32 runKey = keccak256(abi.encodePacked(codeId, runNonce));
        uint256 newCount = ++shardCountForRun[runKey];

        emit ShardSubmitted(codeId, runNonce, msg.sender, shardCid, newCount);

        if (newCount >= committeeThreshold) {
            emit ExecutionApproved(
                codeId,
                runNonce,
                committeeThreshold,
                newCount
            );
        }
    }
}
