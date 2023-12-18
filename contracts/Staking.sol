// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    bool public tokenLaunched;
    IERC721 public nft;
    IERC20 public token;

    uint256 public totalStakedNFTCount;
    uint256 public totalClaimedTokenAmount;
    uint256[] private rewardsPerDay = [
        1 * 10 ** 18,
        2 * 10 ** 18,
        3 * 10 ** 18
    ];

    struct StakingInfo {
        address staker;
        uint256 stakedTime;
        uint256 monthPlan;
    }

    mapping(uint256 => StakingInfo) public tokenIdToStakingInfo;
    mapping(address => uint256[]) public userStakingNfts;

    event NftStaked(address staker, uint256 nftID, uint256 time);
    event NftUnstaked(address staker, uint256 nftID, uint256 time);
    event TokenClaimed(address staker, uint256 amount, uint256 time);

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

    function stakeNFT(uint256[] memory _tokenIDs, uint256 _monthPlan) external {
        require(
            _monthPlan == 0 || _monthPlan == 1 || _monthPlan == 2,
            "Invalid month plan"
        );

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            tokenIdToStakingInfo[_tokenIDs[i]] = StakingInfo({
                staker: msg.sender,
                stakedTime: block.timestamp,
                monthPlan: _monthPlan
            });

            addNftIdToStaker(msg.sender, _tokenIDs[i]);
            nft.transferFrom(msg.sender, address(this), _tokenIDs[i]);
        }

        totalStakedNFTCount += _tokenIDs.length;
    }

    function unstakeNFT(uint256[] memory _tokenIDs) external {
        uint256 currentTime = block.timestamp;
        uint256 oneMonthInSeconds = 30 days;

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            StakingInfo storage info = tokenIdToStakingInfo[_tokenIDs[i]];
            require(info.staker == msg.sender, "Unauthorized unstake");

            uint256 timeDifference = currentTime - info.stakedTime;
            require(timeDifference >= oneMonthInSeconds, "Invalid unstake");

            nft.transferFrom(address(this), msg.sender, _tokenIDs[i]);
            removeNftIdFromStaker(msg.sender, _tokenIDs[i]);
        }

        totalStakedNFTCount -= _tokenIDs.length;
    }

    function calculateReward(uint256 _tokenID) public view returns (uint256) {
        uint256 timePassed = block.timestamp -
            tokenIdToStakingInfo[_tokenID].stakedTime; // Calculate the time passed since staking
        uint256 daysPassed = timePassed / 1 days; // Convert the time passed to days
        uint256 reward = daysPassed *
            rewardsPerDay[tokenIdToStakingInfo[_tokenID].monthPlan]; // Calculate the total reward based on days passed and reward per day
        return reward;
    }

    function claimRewards(uint256[] calldata _tokenIDs) public {
        require(tokenLaunched, "Cannnot claim!");
        uint256 rewards = 0;
        for (uint256 i; i < _tokenIDs.length; i++) {
            require(
                tokenIdToStakingInfo[_tokenIDs[i]].staker == msg.sender,
                "Invalid staker!"
            );
            rewards += calculateReward(_tokenIDs[i]);
            tokenIdToStakingInfo[_tokenIDs[i]].stakedTime = block.timestamp;
        }
        totalClaimedTokenAmount += rewards;
        token.transfer(msg.sender, rewards);
    }

    function getTotalRewards(address user) public view returns (uint256) {
        uint256 temp = 0;
        uint256 rewardsPerNFT = 0;
        for (uint256 i; i < userStakingNfts[user].length; i++) {
            rewardsPerNFT = calculateReward(userStakingNfts[user][i]);
            temp += rewardsPerNFT;
        }
        return temp;
    }

    function getRewardsPerDay(address user) public view returns (uint256) {
        uint256 temp = 0;
        uint256 rewardsPerNFT = 0;
        for (uint256 i; i < userStakingNfts[user].length; i++) {
            rewardsPerNFT = rewardsPerDay[
                tokenIdToStakingInfo[userStakingNfts[user][i]].monthPlan
            ];
            temp += rewardsPerNFT;
        }
        return temp;
    }
}
