// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Tekiostaking {
    bool public tokenLaunched;
    IERC721 public nft;
    IERC20 public token;

    uint256 public totalStakedNFTCount;
    uint256 public totalClaimedTokenAmount;

    uint256 public constant BRONZE_REWARD = 400 * 10 ** 18;
    uint256 public constant SILVER_REWARD = 1200 * 10 ** 18;
    uint256 public constant GOLD_REWARD = 3200 * 10 ** 18;
    uint256 public constant DIAMOND_REWARD = 5200 * 10 ** 18;

    uint256 public boxCounter = 0;
    mapping(uint256 => uint256) public boxNumToType;

    mapping(address => uint256[]) public userStakingNfts;
    mapping(address => uint256[]) public userBoxIds;
    mapping(address => uint256) public userLastClaimedTime;

    mapping(uint256 => bool) public boxClaimed;
    mapping(address => uint256) public tokenClaimedAmount;

    event NftStaked(address staker, uint256 nftID, uint256 time);
    event NftUnstaked(address staker, uint256 nftID, uint256 time);
    event TokenClaimed(address staker, uint256 amount, uint256 time);

    event MisteryBoxClaimed(
        address claimer,
        uint256 misteryBoxCounter,
        uint256 claimedTime
    );

    event StakedNFTs(address staker, uint256 nftCount, uint256 stakingTime);

    event RedeemedMisteryBox(
        address user,
        uint256 misteryBoxID,
        uint256 tokenAmount,
        uint256 time
    );

    constructor(address nftAddr) {
        nft = IERC721(nftAddr);
        tokenLaunched = false;
    }

    function setTokenLaunch(address tokenAddr) external {
        require(tokenAddr != address(0), "Invalid Token Addr");
        tokenLaunched = true;
        token = IERC20(tokenAddr);
    }

    function addNftIdToStaker(address user, uint256 tokenID) internal {
        userStakingNfts[user].push(tokenID);
    }

    function removeNftIdFromStaker(address user, uint256 tokenID) internal {
        uint256[] storage nftIds = userStakingNfts[user];
        for (uint i = 0; i < nftIds.length; i++) {
            if (nftIds[i] == tokenID) {
                nftIds[i] = nftIds[nftIds.length - 1];
                nftIds.pop();
                break;
            }
        }
    }

    function addBoxToStaker(address user, uint256 boxID) internal {
        userBoxIds[user].push(boxID);
    }

    function removeBoxFromStaker(address user, uint256 boxID) internal {
        uint256[] storage boxIds = userBoxIds[user];
        for (uint i = 0; i < boxIds.length; i++) {
            if (boxIds[i] == boxID) {
                boxIds[i] = boxIds[boxIds.length - 1];
                boxIds.pop();
                break;
            }
        }
    }

    function stakeNFT(uint256[] memory _tokenIDs) external {
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            // tokenIdToStakingInfo[_tokenIDs[i]] = StakingInfo(block.timestamp);
            addNftIdToStaker(msg.sender, _tokenIDs[i]);
            nft.transferFrom(msg.sender, address(this), _tokenIDs[i]);
        }

        userLastClaimedTime[msg.sender] = block.timestamp;

        totalStakedNFTCount += _tokenIDs.length;

        emit StakedNFTs(msg.sender, _tokenIDs.length, block.timestamp);
    }

    function exists(
        uint256 num,
        uint256[] memory arr
    ) public view returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            if (arr[i] == num) {
                return true;
            }
        }

        return false;
    }

    function getBox(address staker) public view returns (uint256) {
        if (
            userStakingNfts[staker].length >= 1 &&
            userStakingNfts[staker].length <= 3
        ) return 1;
        if (
            userStakingNfts[staker].length >= 4 &&
            userStakingNfts[staker].length <= 9
        ) return 2;
        if (
            userStakingNfts[staker].length >= 10 &&
            userStakingNfts[staker].length <= 18
        ) return 3;
        if (userStakingNfts[staker].length >= 19) return 4;
        else return 0;
    }

    function getPassedWeeks(address staker) public view returns (uint256) {
        return (block.timestamp - userLastClaimedTime[staker]) / 1 weeks;
    }

    function boxClaimable(address staker) external view returns (bool) {
        return block.timestamp >= userLastClaimedTime[staker] + 5 minutes;
    }

    function claimBox() external {
        require(
            block.timestamp > userLastClaimedTime[msg.sender] + 5 minutes, // updated
            "not passed period"
        );

        require(userStakingNfts[msg.sender].length > 0, "not staked NFTs");

        userBoxIds[msg.sender].push(boxCounter);
        boxNumToType[boxCounter] = getBox(msg.sender);
        boxCounter++;
        userLastClaimedTime[msg.sender] = block.timestamp;
    }

    function random(uint256 startNum, uint256 endNum) internal returns (uint) {
        uint randomnumber = uint(
            keccak256(
                abi.encodePacked(block.timestamp, msg.sender, block.timestamp)
            )
        ) % (startNum + endNum);
        randomnumber = randomnumber + startNum;
        return randomnumber;
    }

    function reedeemBox(uint256 boxID) external {
        require(exists(boxID, userBoxIds[msg.sender]), "not box owner");
        removeBoxFromStaker(msg.sender, boxID);
        uint tokenAmount = 0;
        if (boxNumToType[boxID] == 1) {
            tokenAmount = BRONZE_REWARD;
        } else if (boxNumToType[boxID] == 2) {
            tokenAmount = SILVER_REWARD;
        } else if (boxNumToType[boxID] == 3) {
            tokenAmount = GOLD_REWARD;
        } else if (boxNumToType[boxID] == 4) {
            tokenAmount = DIAMOND_REWARD;
        }
        token.transfer(msg.sender, tokenAmount);
        tokenClaimedAmount[msg.sender] += tokenAmount;
    }

    function unstakeNFT(uint256[] memory _tokenIDs) external {
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            require(
                exists(_tokenIDs[i], userStakingNfts[msg.sender]),
                "not token owner"
            );
            nft.transferFrom(address(this), msg.sender, _tokenIDs[i]);
            removeNftIdFromStaker(msg.sender, _tokenIDs[i]);
        }
        totalStakedNFTCount -= _tokenIDs.length;
    }

    function getStakedNFTs(
        address staker
    ) external view returns (uint256[] memory) {
        return userStakingNfts[staker];
    }

    function getBoxids(
        address staker
    ) external view returns (uint256[] memory) {
        return userBoxIds[staker];
    }
}
